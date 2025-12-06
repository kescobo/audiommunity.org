using CSV
using DataFrames
using Distributions
using Random
using StableRNGs
using InformationMeasures
using MultivariateStats
using StatsBase
using CairoMakie
using Distances

proteins = CSV.read("somascan.tsv", DataFrame; delim='\t', stringtype=String)

# from STable 1 - genotypes 22, 23, 33, 24, 34, 44
genotypes = (;
    nic = [2, 51, 364, 10, 129,17],
    ad = [1, 24, 263, 10, 189, 39],
    pd = [1, 31, 155, 4, 52, 4]
)
participants = NamedTuple(d => sum(genotypes[d]) for d in keys(genotypes))

# Generating random data

rng = StableRNG(20251204) # today's date

df = DataFrame(diagnosis = sample(rng,
        collect(keys(participants)),
        fweights(collect(values(participants))), #weights
        sum(values(participants))
    )
)
df.genotype = [
    sample(rng, ["22", "23", "33", "24", "34", "44"],
            fweights(genotypes[d])) for d in df.diagnosis
]
# is apoe4+?
df.apoe4cnt = count.(==('4'), df.genotype)
df.apoe4pos = df.apoe4cnt .> 0

for u in proteins.uniprot
    df[:, u] = rand(rng, Normal(), nrow(df))
end

let nic = subset(df, "diagnosis"=>ByRow(==(:nic)))
    proteins.mi_cnt = [get_mutual_information(nic[:, u], nic.apoe4cnt) for u in proteins.uniprot]
    proteins.mi_pos = [get_mutual_information(nic[:, u], nic.apoe4pos) for u in proteins.uniprot]
end

# Figure 1

fig = Figure(;size=(600,200));
ax1 = Axis(fig[1,1]; xlabel = "MI", ylabel="N", title="allele count")
ax2 = Axis(fig[1,2]; xlabel = "MI", ylabel="N", title="apoe+")

hist!(ax1, proteins.mi_cnt)
hist!(ax2, proteins.mi_pos)

save("mi_distributions.png", fig)
fig

# Enrichments

open(io-> println.(io, proteins.uniprot), "all_uniprot.txt", "w")

open("rand_uniprot.txt", "w") do io
    for u in sample(proteins.uniprot, 250; replace=false)
        println(io, u)
    end
end

open("cnt_uniprot.txt", "w") do io
    us = sort(proteins, "mi_cnt"; rev=true)
    println.(io, us[1:250, "uniprot"])
end

open("pos_uniprot.txt", "w") do io
    us = sort(proteins, "mi_pos"; rev=true)
    println.(io, us[1:250, "uniprot"])
end

# PCA

fig = Figure(;size=(600,200));
ax1 = Axis(fig[1,1]; xlabel = "PC.1", ylabel="PC.2", title="all proteins")
ax2 = Axis(fig[1,2]; xlabel = "PC.1", ylabel="PC.2", title="top MI count")

pca = fit(PCA, Matrix(df[:, 4:end]));
scatter!(ax1, projection(pca)[:,1], projection(pca)[:,2]; color = df.apoe4cnt)

let us = sort(proteins, "mi_cnt"; rev=true)
    pca = fit(PCA, Matrix(select(df, unique(us.uniprot[1:200]))))
    scatter!(ax2, projection(pca)[:,1], projection(pca)[:,2]; color = df.apoe4cnt)
end

fig

# Add more correlation
df2 = copy(df)
for i in 5:ncol(df2)
    if rand(rng) < 0.01
        sign = rand(Bool) ? -0.5 : 0.5
        df2[:, i] = df2[:, i] .+ map(df2.apoe4cnt) do a
            a * rand(Normal(rand() * sign))
        end
    end
end

let nic = subset(df2, "diagnosis"=>ByRow(==(:nic)))
    proteins.mi_cnt2 = [get_mutual_information(nic[:, u], nic.apoe4cnt) for u in proteins.uniprot]
    proteins.mi_pos2 = [get_mutual_information(nic[:, u], nic.apoe4pos) for u in proteins.uniprot]
end

# Figure 1

fig = Figure(;size=(600,200));
ax1 = Axis(fig[1,1]; xlabel = "MI", ylabel="N", title="allele count")
ax2 = Axis(fig[1,2]; xlabel = "MI", ylabel="N", title="apoe+")

hist!(ax1, proteins.mi_cnt2)
hist!(ax2, proteins.mi_pos2)

save("mi_add_distributions.png", fig)
fig


fig = Figure(;size=(400,200));
ax1 = Axis(fig[1,1]; xlabel = "PC.1", ylabel="PC.2", title="all proteins")
ax2 = Axis(fig[1,2]; xlabel = "PC.1", ylabel="PC.2", title="top MI count")

pca = fit(PCA, Matrix(df2[:, 4:end]));
scatter!(ax1, projection(pca)[:,1], projection(pca)[:,2]; color = df.apoe4cnt)

let us = sort(proteins, "mi_cnt2"; rev=true)
    pca = fit(PCA, Matrix(select(df2, unique(us.uniprot[1:200]))))
    scatter!(ax2, projection(pca)[:,1], projection(pca)[:,2]; color = df.apoe4cnt)
end

fig

open("cnt2_uniprot.txt", "w") do io
    us = sort(proteins, "mi_cnt"; rev=true)
    println.(io, us[1:250, "uniprot"])
end

open("pos_uniprot.txt", "w") do io
    us = sort(proteins, "mi_pos"; rev=true)
    println.(io, us[1:250, "uniprot"])
end
