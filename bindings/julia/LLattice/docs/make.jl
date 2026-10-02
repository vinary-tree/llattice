using Documenter
using LLattice

const DOCS_ROOT = @__DIR__

makedocs(
    root=DOCS_ROOT,
    modules=[LLattice],
    sitename="LLattice.jl",
    format=Documenter.HTML(repolink="https://github.com/vinary-tree/llattice"),
    pages=["Home" => "index.md"],
    build="build",
    checkdocs=:exports,
    repo="https://github.com/vinary-tree/llattice/blob/{commit}{path}#{line}",
    warnonly=false,
)

if get(ENV, "LLATTICE_DOCS_DEPLOY", "") == "1"
    isfile(joinpath(DOCS_ROOT, "build", "index.html")) ||
        error("LLattice.jl documentation build is missing its index page")
    deploydocs(
        root=DOCS_ROOT,
        target="build",
        repo="github.com/vinary-tree/llattice.git",
        devbranch="master",
    )
end
