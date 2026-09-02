use llattice::{JoinSemilattice, MeetSemilattice};
use std::collections::HashSet;
use std::env;
use std::fs::{self, File};
use std::hint::black_box;
use std::io::{BufWriter, Write};
use std::path::PathBuf;
use std::process;
use std::time::Instant;

const SET_SIZE: u64 = 16_384;

struct Config {
    arm: String,
    output: PathBuf,
    samples: usize,
    warmups: usize,
}

fn usage() -> ! {
    eprintln!(
        "usage: hot_paths --arm <control|treatment> --output \
         <target/path.csv> [--samples N] [--warmups N]"
    );
    process::exit(2);
}

fn parse_usize(value: Option<String>) -> usize {
    value
        .and_then(|raw| raw.parse().ok())
        .unwrap_or_else(|| usage())
}

fn config() -> Config {
    let mut args = env::args().skip(1);
    let mut arm = None;
    let mut output = None;
    let mut samples = 51;
    let mut warmups = 3;

    while let Some(argument) = args.next() {
        match argument.as_str() {
            "--arm" => arm = args.next(),
            "--output" => output = args.next().map(PathBuf::from),
            "--samples" => samples = parse_usize(args.next()),
            "--warmups" => warmups = parse_usize(args.next()),
            "--bench" => {}
            _ => usage(),
        }
    }

    let arm = arm.unwrap_or_else(|| usage());
    if arm != "control" && arm != "treatment" {
        usage();
    }
    if samples < 51 || warmups < 3 {
        eprintln!("the pre-registered protocol requires at least 51 samples and 3 warm-ups");
        process::exit(2);
    }

    let output = output.unwrap_or_else(|| usage());
    if output.is_absolute() || !output.starts_with("target") {
        eprintln!("benchmark output must be a repository-local path under target/");
        process::exit(2);
    }

    Config {
        arm,
        output,
        samples,
        warmups,
    }
}

fn run_metric<F>(
    writer: &mut BufWriter<File>,
    config: &Config,
    metric: &str,
    operations_per_sample: usize,
    mut operation: F,
) where
    F: FnMut(),
{
    for _ in 0..config.warmups {
        for _ in 0..operations_per_sample {
            operation();
        }
    }

    for sample in 0..config.samples {
        let started = Instant::now();
        for _ in 0..operations_per_sample {
            operation();
        }
        let nanoseconds = started.elapsed().as_nanos() as f64 / operations_per_sample as f64;
        writeln!(
            writer,
            "{},{},{},{nanoseconds:.6},false",
            config.arm, metric, sample
        )
        .expect("write benchmark sample");
    }
}

fn main() {
    // `cargo test --all-targets` may forward arbitrary test-harness flags.
    // Compilation is the desired smoke check unless `cargo bench` supplies
    // its explicit `--bench` marker.
    if !env::args_os().any(|argument| argument == "--bench") {
        return;
    }

    let config = config();
    if let Some(parent) = config.output.parent() {
        fs::create_dir_all(parent).expect("create benchmark output directory");
    }
    let output = File::create(&config.output).expect("create benchmark output");
    let mut writer = BufWriter::new(output);
    writeln!(writer, "arm,metric,sample,value_ns,is_warmup").expect("write CSV header");

    let mut integer_accumulator = 0_i64;
    let mut integer_incoming = 1_i64;
    run_metric(
        &mut writer,
        &config,
        "i64_join_ns_per_op",
        1_000_000,
        || {
            integer_accumulator = black_box(integer_accumulator).join(black_box(&integer_incoming));
            integer_incoming = black_box(integer_incoming.wrapping_add(1));
        },
    );
    black_box(integer_accumulator);

    let mut option_accumulator = Some(0_i64);
    let mut option_incoming = Some(1_i64);
    run_metric(
        &mut writer,
        &config,
        "option_i64_join_ns_per_op",
        500_000,
        || {
            option_accumulator = black_box(option_accumulator).join(black_box(&option_incoming));
            option_incoming = Some(black_box(option_incoming.unwrap_or(0).wrapping_add(1)));
        },
    );
    black_box(option_accumulator);

    let left: HashSet<u64> = (0..SET_SIZE).collect();
    let right: HashSet<u64> = (SET_SIZE / 2..SET_SIZE + SET_SIZE / 2).collect();
    run_metric(
        &mut writer,
        &config,
        "hashset_join_16384_ns_per_op",
        8,
        || {
            black_box(black_box(&left).join(black_box(&right)));
        },
    );
    let mut assign_accumulator = left.clone();
    assert!(assign_accumulator.join_assign(&right));
    run_metric(
        &mut writer,
        &config,
        "hashset_join_assign_stable_16384_ns_per_op",
        16,
        || {
            black_box(assign_accumulator.join_assign(black_box(&right)));
        },
    );
    run_metric(
        &mut writer,
        &config,
        "hashset_meet_16384_ns_per_op",
        16,
        || {
            black_box(black_box(&left).meet(black_box(&right)));
        },
    );

    writer.flush().expect("flush benchmark samples");
}
