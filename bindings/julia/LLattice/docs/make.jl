using Documenter
using LLattice

makedocs(
    modules=[LLattice],
    sitename="LLattice.jl",
    format=Documenter.HTML(repolink="https://github.com/vinary-tree/llattice"),
    pages=["Home" => "index.md"],
    checkdocs=:exports,
    repo="https://github.com/vinary-tree/llattice/blob/{commit}{path}#{line}",
    warnonly=false,
)

if get(ENV, "LLATTICE_DOCS_DEPLOY", "") == "1"
    deploydocs(
        repo="github.com/vinary-tree/llattice.git",
        devbranch="main",
        push_preview=true,
    )
end
