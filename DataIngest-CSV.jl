### A Pluto.jl notebook ###
# v0.19.27

using Markdown
using InteractiveUtils

# ╔═╡ 5e20f270-c8c4-4cb3-88ff-67bccfa8a026
using CSV

# ╔═╡ b8df28ed-8788-4bff-857e-8fd0ebcf151a
using Statistics

# ╔═╡ 0e9a3666-ddb6-48c6-9951-d08c0b6c2e5b
using DataFrames

# ╔═╡ a246fa20-0417-48ed-8422-dc1c9909e068
md"""# _Working with DataFrames.jl beyond CSV_
### Jacob Quinn
"""

# ╔═╡ 80e8cb31-3260-4388-89d5-e5c935313318
md"""# Part 4: _Data Ingestion via CSV.jl_


##### Ok, ok, I know the name of the talk is "DataFrames _beyond_ CSV", but we need to talk about CSV, right??
\

As one of the most common data formats, let's discuss briefly the various ways the CSV.jl package helps process CSV data:
\
"""

# ╔═╡ 2e335fde-13f0-4550-91aa-63a8c81bbcd4
md"""
|                           | CSV.File | CSV.Chunks | CSV.Rows |
|---------------------------|----------|------------|----------|
| Automatic Type Inference  | ✅        | ✅          |          |
| Produces Columnar Results | ✅        | ✅          |          |
| Process Files Iteratively |          | ✅          | ✅        |
| Low Memory Requirements   |          | ✅*         | ✅        |
"""

# ╔═╡ 0ce424e0-24e1-11ee-166a-a74982731348
md"""
Data downloaded from [here](https://drive.google.com/file/d/1LJ5ftwOJbJtXVjDjWa3btuDPTYpAcGbh/view?usp=sharing) (NOTE: this is a gzipped file around ~350MB, 1GB uncompressed!)
"""

# ╔═╡ ab4afff2-8c1d-438c-a2dc-be91179ce27d
md"""
First, let's take a look at `CSV.File`. The constructor for this takes a delimited file name, byte buffer, `Cmd` or `IO`, along with any keyword arguments to control types, parsing details, etc.
"""

# ╔═╡ 3ed1f46a-3636-4063-a29d-b2371082b9fa
f = CSV.File("/Users/quinnj/randoms.csv"; header=["id", "Fname", "Lname", "Salary", "Wage", "StartDate", "TermDate"])

# ╔═╡ 1f349016-e72f-4f4a-bd19-e5cde32ff7ec
md"""
We can see that calling `CSV.File` parsed and materialized the full file, and that results are displayed in columns. Column types were "inferred" while parsing, and any necessary promotion is taken care of automatically. We can see that integers, strings, dates, and datetimes were all automatically inferred.
 \ 

 
We can see the inferred column names and types by accessing fields:
"""

# ╔═╡ 603910fa-fb31-4975-9871-248016ecc08a
f.names

# ╔═╡ 635ad9e6-7065-4e90-a272-f4819bd87658
f.types

# ╔═╡ af85f012-6fbd-4d42-a709-707b1e8bbb28
md"""
We can access results row-by-row, or as entire columns.
"""

# ╔═╡ 05aacd94-34f7-497f-81ea-8815535b2965
avg_wage = begin
	sum_wage = 0.0
	for row in f
		sum_wage += coalesce(row.Wage, 0.0)
	end
	sum_wage / length(f)
end

# ╔═╡ 25870155-c5d1-4d69-8c34-b6381cc954fb
avg_wage_col = mean(skipmissing(f.Wage))

# ╔═╡ 26392e89-44c9-4659-b90c-913f0840623b
md"""
We can also materialize the results in a DataFrame (obviously)!
"""

# ╔═╡ 93963ecf-f7ac-46ec-a90e-3ed01e0fa35f
# ╠═╡ disabled = true
#=╠═╡
df = DataFrame(f)
  ╠═╡ =#

# ╔═╡ 9f85e039-fc43-4227-8111-68e231a7467f
md"""
But what exactly happened when we did that? Did we make a copy of the data? Or is the `CSV.File` object and `DataFrame` _sharing_ the data?
"""

# ╔═╡ b4901aaf-729a-42dc-b665-7bd580ae1d11
#=╠═╡
f.id == df.id
  ╠═╡ =#

# ╔═╡ b74787e2-60da-4534-b530-b37c9c67b34c
#=╠═╡
f.id === df.id
  ╠═╡ =#

# ╔═╡ b4694b9b-c222-4be8-978f-522e1324adf6
md"""
Ok, so they're _not_ sharing data, so a copy was made! I guess that's safe if I'm doing operations on the `CSV.File` and `DataFrame` separately and don't mean to modify both. But what if I _don't_ want to make a copy, for efficiency?
"""

# ╔═╡ 2e902fdf-eeba-4cc3-8b38-ae6d417552b8
df_no_copy = DataFrame(f; copycols=false)

# ╔═╡ e9cc0eab-9052-4c7b-b721-392e22709abc
f.id === df_no_copy.id

# ╔═╡ 89f956a4-093e-4bff-b01d-10c8eb91c1f0
md"""
Alternatively, CSV.jl provides the `CSV.read` function, which does this for us automatically.
"""

# ╔═╡ e8212439-a98f-4d62-a2f7-7c21080f37f7
df_no_copy2 = CSV.read("/Users/quinnj/randoms.csv", DataFrame; header=["id", "Fname", "Lname", "Salary", "Wage", "StartDate", "TermDate"])

# ╔═╡ 96471b78-45b3-415e-b8b2-e77235cff103
md"""
Because there's no intermediate `CSV.File`, the column results were materialized directly into the `DataFrame`.
 \


How does this work since CSV.jl doesn't depend on DataFrames.jl? How do they know how to talk to each other? The answer is in the Tables.jl package.
 \


Tables.jl provides interfaces that table sources can overload so the source rows or columns can be accessed in a generic way by table consumers. So in this case, `CSV.File` overloads the Tables.jl accessor functions, and then DataFrames.jl _uses_ the Tables.jl API to make columns.
"""

# ╔═╡ 82a578e0-3af9-4811-a402-8c86c5414fe7
md"""
### `CSV.Chunks`
 \

Ok, so `CSV.File` sounds pretty nifty, but what if my delimited file is on the larger side and I can't or don't want to materialize the full thing in memory?
 \


`CSV.Chunks` provides almost an identical interface to `CSV.File` (i.e. give it any of the same delimited sources, keyword args, etc), but also supports an additional `ntasks` keyword argument which specifies how many "chunks" a file should be split up into. Calling `CSV.Chunks` returns, you guessed it, a `CSV.Chunks` object. So what can you do with a `CSV.Chunks`? It's interface is very simple, all you can do is iterate it, where each iteration produces a `CSV.File` object of a subset of the entire data source. That means on each iteration, the entire chunk is materialized like `CSV.File` where column names, types, and values-in-columns are available as before. Let's see this in action.
"""

# ╔═╡ b8277719-37f7-4fcc-8350-4310a596d7c7
avg_wage_chunked = begin
	sum_wage2 = 0.0
	count = 0
	for chunk in CSV.Chunks("/Users/quinnj/randoms.csv"; header=["id", "Fname", "Lname", "Salary", "Wage", "StartDate", "TermDate"])
		sum_wage2 += sum(skipmissing(chunk.Wage))
		count += length(chunk)
	end
	sum_wage2 / count
end

# ╔═╡ dfd8eae6-4826-4434-a16c-5d5c1e023713
md"""
By default, `CSV.Chunks` will split into `Threads.nthreads()` iterations, unless there's only 1 thread available, in which case it will split into 8 chunks. As mentioned above, this is controllable via the `ntasks` keyword argument.
  \


The advantages of `CSV.Chunks` is that we can get the benefits of `CSV.File` (columnar results, type inference) while still being able to process extremely large data.
"""

# ╔═╡ fdbdfee3-ed32-4f2f-b1f7-2b5f5c58686b
md"""### `CSV.Rows`
 \

Another alternative way to process delimited files is via `CSV.Rows`, which is focused on providing an efficient, lowest-memory footprint iterator over delimited rows. A major tradeoff of focusing on processing one row at a time, however, is giving up automatic type inference. Users can still pass an explicit set of types to be parsed.
"""

# ╔═╡ 222cbc93-6aba-4c75-812f-85bc063a3639
avg_wage_rows = begin
	sum_wage3 = 0.0
	count3 = 0
	for row in CSV.Rows("/Users/quinnj/randoms.csv"; header=["id", "Fname", "Lname", "Salary", "Wage", "StartDate", "TermDate"], types=Dict("Wage" => Float64))
		sum_wage3 += coalesce(row.Wage, 0.0)
		count3 += 1
	end
	sum_wage3 / count3
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[compat]
CSV = "~0.10.11"
DataFrames = "~1.6.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.0-rc1"
manifest_format = "2.0"
project_hash = "f053f06262d956a6474da3cf50e271109a8590a6"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "PrecompileTools", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "44dbf560808d49041989b8a96cae4cffbeb7966a"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.11"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "02aa26a4cf76381be7f66e020a3eddeb27b0a092"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.2"

[[deps.Compat]]
deps = ["UUIDs"]
git-tree-sha1 = "4e88377ae7ebeaf29a047aa1ee40826e0b708a5d"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.7.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.2+0"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "8da84edb865b0b5b0100c0666a9bc9a0b71c553c"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.15.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrecompileTools", "PrettyTables", "Printf", "REPL", "Random", "Reexport", "SentinelArrays", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "089d29c0fc00a190661517e4f3cba5dcb3fd0c08"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.6.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "cf25ccb972fec4e4817764d01c82386ae94f77b4"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.14"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "e27c4ebe80e8699540f2d6c805cc12203b614f12"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.20"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "9cc2baf75c6d09f9da536ddf58eb2f29dedaf461"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InvertedIndices]]
git-tree-sha1 = "0dc7b50b8d436461be01300fd8cd45aa0274b038"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+0"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "f66bdc5de519e8f8ae43bdc598782d35a25b1272"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.1.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.10.11"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.21+4"

[[deps.OrderedCollections]]
git-tree-sha1 = "d321bf2de576bf25ec4d3e4360faca399afca282"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.0"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "4b2e829ee66d4218e0cef22c0a64ee37cf258c29"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.7.1"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.9.0"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a6062fe4063cdafe78f4a0a81cfffb89721b30e7"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.2"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "9673d39decc5feece56ef3940e5dafba15ba0f81"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.1.2"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "7eb1686b4f04b82f96ed7a4ea5890a4f0c7a09f1"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.0"

[[deps.PrettyTables]]
deps = ["Crayons", "Formatting", "LaTeXStrings", "Markdown", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "331cc8048cba270591eab381e7aa3e2e3fef7f5e"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.2.5"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "04bdff0b09c65ff3e06a05e3eb7b120223da3d39"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "c60ec5c62180f27efea3ba2908480f8055e17cee"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.1.1"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.9.0"

[[deps.StringManipulation]]
git-tree-sha1 = "46da2434b41f41ac3594ee9816ce5541c6096123"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.3.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "Pkg", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "5.10.1+6"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "1544b926975372da01227b382066ab70e574a3ec"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.10.1"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "9a6ae7ed916312b41236fcef7e0af564ef934769"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.13"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.WorkerUtilities]]
git-tree-sha1 = "cd1659ba0d57b71a464a29e64dbc67cfe83d54e7"
uuid = "76eceee3-57b5-4d4a-8e66-0e911cebbf60"
version = "1.6.1"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.4.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"
"""

# ╔═╡ Cell order:
# ╟─a246fa20-0417-48ed-8422-dc1c9909e068
# ╟─80e8cb31-3260-4388-89d5-e5c935313318
# ╠═2e335fde-13f0-4550-91aa-63a8c81bbcd4
# ╟─0ce424e0-24e1-11ee-166a-a74982731348
# ╟─ab4afff2-8c1d-438c-a2dc-be91179ce27d
# ╠═5e20f270-c8c4-4cb3-88ff-67bccfa8a026
# ╠═3ed1f46a-3636-4063-a29d-b2371082b9fa
# ╟─1f349016-e72f-4f4a-bd19-e5cde32ff7ec
# ╠═603910fa-fb31-4975-9871-248016ecc08a
# ╠═635ad9e6-7065-4e90-a272-f4819bd87658
# ╟─af85f012-6fbd-4d42-a709-707b1e8bbb28
# ╠═05aacd94-34f7-497f-81ea-8815535b2965
# ╠═b8df28ed-8788-4bff-857e-8fd0ebcf151a
# ╠═25870155-c5d1-4d69-8c34-b6381cc954fb
# ╟─26392e89-44c9-4659-b90c-913f0840623b
# ╠═0e9a3666-ddb6-48c6-9951-d08c0b6c2e5b
# ╠═93963ecf-f7ac-46ec-a90e-3ed01e0fa35f
# ╟─9f85e039-fc43-4227-8111-68e231a7467f
# ╠═b4901aaf-729a-42dc-b665-7bd580ae1d11
# ╠═b74787e2-60da-4534-b530-b37c9c67b34c
# ╠═b4694b9b-c222-4be8-978f-522e1324adf6
# ╠═2e902fdf-eeba-4cc3-8b38-ae6d417552b8
# ╠═e9cc0eab-9052-4c7b-b721-392e22709abc
# ╟─89f956a4-093e-4bff-b01d-10c8eb91c1f0
# ╠═e8212439-a98f-4d62-a2f7-7c21080f37f7
# ╟─96471b78-45b3-415e-b8b2-e77235cff103
# ╟─82a578e0-3af9-4811-a402-8c86c5414fe7
# ╠═b8277719-37f7-4fcc-8350-4310a596d7c7
# ╟─dfd8eae6-4826-4434-a16c-5d5c1e023713
# ╟─fdbdfee3-ed32-4f2f-b1f7-2b5f5c58686b
# ╠═222cbc93-6aba-4c75-812f-85bc063a3639
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
