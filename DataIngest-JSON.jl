### A Pluto.jl notebook ###
# v0.19.27

using Markdown
using InteractiveUtils

# ╔═╡ ee7876c2-3d8c-4fef-81bb-7d529c859b3f
using JSON3, JSONTables, DataFrames, CSV

# ╔═╡ ae7e03e1-7289-4ddb-b892-8cc3ac241594
using Dates

# ╔═╡ 91fbe57a-2a6b-11ee-22e6-415877198985
md"""# _Working with DataFrames.jl beyond CSV_
### Jacob Quinn
"""

# ╔═╡ 8a44419a-8e0c-43b7-85d4-e42b62a93f62
md"""# Part 6: _Data Ingestion with JSON data_


#### JSON Primer

###### JSON data is a simple, text-based data format that is human readable, and extensively used across the web. It is _mostly_ structured, though the specification is a bit loose and leads to slight variations in actual language implementations. Officially, JSON supports numbers, booleans, strings, and null as atom values, with objects (pairs of keys and values) and arrays as structured values. 

When it comes to table-like data, there are 2 common ways JSON data can represent table data. One is an array of objects, which can be seen as a row-oriented representation. Each element of the array is an object, and objects are expected to share the same keys and value types as the table schema. The second is an object of arrays, where the object keys are column names, and the object values are entire arrays of column values.


#### Getting Started With JSON

Ok, so how do we work with JSON in Julia? I'll be focusing on the abilities provided by the JSON3.jl and JSONTables.jl packages, though there are other options available providing similar abilities. As with Arrow.jl, let's first start with how we take table data and get it into the JSON format.
"""
# What is JSON data
# 2 table-like formats
# input/output
# options for flattening?
# future plans

# ╔═╡ e1d743fc-e3f6-4bf1-9ee1-9ffeeb658b43
md"""
Data downloaded from [here](https://drive.google.com/file/d/1LJ5ftwOJbJtXVjDjWa3btuDPTYpAcGbh/view?usp=sharing) (NOTE: this is a gzipped file around ~350MB, 1GB uncompressed!). Alternatively, a much smaller subset of the data can be downloaded [here](https://drive.google.com/file/d/1Lde1DZwBHmomm9TOg5L4kP-vPNkymSNP/view?usp=sharing). To make subsequent commands work, edit the following cell to point to the path of whichever file you downloaded.
"""

# ╔═╡ 25985a0a-1c9d-4c5e-8e80-b7ecf7138358
const path = "/Users/quinnj/randoms.csv.gz"

# ╔═╡ ac645907-fe04-408d-ae90-8f6b02b1875b
df = CSV.read(path, DataFrame; header=["id", "Fname", "Lname", "Salary", "Wage", "StartDate", "TermDate"])

# ╔═╡ 8078edad-6b02-40f6-9af2-161d4496daa1
md"""
Ok, we have our `DataFrame` of data, now let's use the `arraytable` and `objecttable` functions from the JSONTables.jl package to write data out to JSON.
"""

# ╔═╡ b1f28379-b038-4195-8b23-97fd5f207796
json_arr = arraytable(df[1:5, :])

# ╔═╡ 174100db-2ec6-4023-8a8b-6d03f55a7df0
JSON3.@pretty json_arr

# ╔═╡ c3174bbd-9235-4311-a52c-9aee4388efc7
json_obj = objecttable(df[1:5, :])

# ╔═╡ dcfc18ea-d388-4228-8f94-c031bc7ce415
JSON3.@pretty json_obj

# ╔═╡ 143bb099-0a68-4453-a147-8328e95923bf
md"""
Here we're taking just 5 rows from our `DataFrame` (for display purposes), and writing them out as JSON "tables", first as an array of objects, then as an object of arrays. One note about the array of objects is that the column names (object keys) are repeated for each "row" (object), which can drastically increase the size of the produced JSON. These 2 functions `arraytable` and `objecttable` are provided by the JSONTables.jl package and use JSON3.jl under the hood in connection with the Tables.jl package.

So that shows us going from table -> JSON, but what about the other way around?
"""

# ╔═╡ 8af25f8b-5411-49c9-9f45-9b8d98fa2329
df_arr = DataFrame(jsontable(json_arr))

# ╔═╡ 23506d89-95fd-466b-90b1-0dec0c2a5555
df_obj = DataFrame(jsontable(json_obj))

# ╔═╡ 45ad8e08-691b-410c-bd26-e922f0019abf
md"""
We're only using a single function in both cases here, `jsontable`, which automatically detects whether the input JSON is an array of objects or an object of arrays, then provides the right Tables.jl interface functions so DataFrames knows what to do.

Let's pause for just a second and take a quick look at our last two columns though:
"""

# ╔═╡ 02514248-e707-4ee5-8813-bdb1bc732e54
df_obj.StartDate

# ╔═╡ 1606f0be-7b88-45a9-a787-5a7cbcc0c064
df_obj.TermDate

# ╔═╡ af8c7676-129e-4628-a42b-b379754337ff
md"""
Our original data/`DataFrame` had `Date` and `Union{DateTime, Missing}` column types, but these are strings! This reveals one of the limitations of the JSON format; there's no native support for custom types, dates, etc. We can overcome this by adding a post-processing step ourselves.
"""

# ╔═╡ 99309821-ed4a-42e1-a4fa-ef8670072377
df_obj.StartDate = Date.(df_obj.StartDate)

# ╔═╡ 82e41123-3dbf-43b9-b0f6-48b3673eae0b
df_obj.TermDate = [ismissing(x) ? missing : DateTime(x) for x in df_obj.TermDate]

# ╔═╡ 947cefcc-4b21-4646-bda1-64aa9f5ee5c9
df_obj

# ╔═╡ 450cfeb3-a32f-4350-93f1-cea2b4d1ee13
md"""
An alternative, more advanced approach is working more closely with the raw JSON data. The JSON3.jl package, integrating with the StructTypes.jl package, provides a way to deserialize JSON directly into typed Julia structs. Let's use our `Person` struct definition from part 5 (arrow).
"""

# ╔═╡ 4a352522-0f5c-4f56-88ce-d8dd5a86c079
# id	Fname	Lname	Salary	Wage	StartDate	TermDate
# Int64	String	String	Int64?	Float64?	Date	DateTime?
struct Person
	id::Int
	Fname::String
	Lname::String
	Salary::Union{Int, Missing}
	Wage::Union{Float64, Missing}
	StartDate::Date
	TermDate::Union{DateTime, Missing}
end

# ╔═╡ 66416e28-8cc2-4575-86cd-2c5cffa9d32b
persons = JSON3.read(json_arr, Vector{Person})

# ╔═╡ 0be5e706-3e73-4467-be3e-a8d46468e277
md"""
Woah! That just worked! Let's step through it:

* We had JSON data that was an array of objects, where each object had the same keys and values of the same type (our person data)
* We defined a Julia struct `Person` with field names and types that match the JSON keys/values
* We called `JSON3.read` with our JSON data as the 1st argument, and a type (`Vector{Person}`) as the 2nd argument
* `JSON3.read` returned an _instance_ of `Vector{Person}`, where each element is a materialized `Person` struct, with even the `Date`/`DateTime` fields fully parsed, and `missing` values accounted for

How does that "just work"? The [StructTypes.jl](https://github.com/JuliaData/StructTypes.jl) package provides utilities for constructing/accessing Julia structs in programmatic ways. By default, Julia structs are treated as "data packages" where each field name + type is part of the data package. JSON3.jl then uses the StructTypes.jl package when a custom struct (`Person` in this case) is requested in the deserialization process.

Ok, that's pretty neat, but does that help me with getting this data into a `DataFrame`?
"""

# ╔═╡ b5002109-9034-4455-831a-7ddb9dc53dc8
df_persons = DataFrame(persons)

# ╔═╡ c7d3e7a9-3b68-4851-8d55-75f018cee2c4
md"""
Woah again! That just works too?? In this case, `persons` is a `Vector{Person}`, and in the Tables.jl interface, a custom struct like `Person` is _also_ treated by default as a "data packet" or "row" where each field name + type is the column name/type of the row, so a `Vector{Person}` is, by default, treated as a "row table", that is, it's a table of rows, where the values on each row are the fields of the `Person` structs. Pretty neat!

This all comes together in a way that makes modelling and working with _domain_ data in Julia via custom structs really easy. Let me say that again in another way: unlike many other "data analysis" frameworks in other languages, it can be a seamless experience to model data in Julia using custom structs, go to-and-from a 2D representation via DataFrames.jl, all with minimal integration needed.

#### Future of JSON

Tune in to my talk on Thursday! 😊
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Dates = "ade2ca70-3891-5945-98fb-dc099432e06a"
JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
JSONTables = "b9914132-a727-11e9-1322-f18e41205b0b"

[compat]
CSV = "~0.10.11"
DataFrames = "~1.6.0"
JSON3 = "~1.13.1"
JSONTables = "~1.0.3"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.0-rc1"
manifest_format = "2.0"
project_hash = "8554fbd42557d2024d6f33684f4f49b4c7c06a58"

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

[[deps.JSON3]]
deps = ["Dates", "Mmap", "Parsers", "PrecompileTools", "StructTypes", "UUIDs"]
git-tree-sha1 = "5b62d93f2582b09e469b3099d839c2d2ebf5066d"
uuid = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
version = "1.13.1"

[[deps.JSONTables]]
deps = ["JSON3", "StructTypes", "Tables"]
git-tree-sha1 = "13f7485bb0b4438bb5e83e62fcadc65c5de1d1bb"
uuid = "b9914132-a727-11e9-1322-f18e41205b0b"
version = "1.0.3"

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

[[deps.StructTypes]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "ca4bccb03acf9faaf4137a9abc1881ed1841aa70"
uuid = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"
version = "1.10.0"

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
# ╟─91fbe57a-2a6b-11ee-22e6-415877198985
# ╠═8a44419a-8e0c-43b7-85d4-e42b62a93f62
# ╠═ee7876c2-3d8c-4fef-81bb-7d529c859b3f
# ╟─e1d743fc-e3f6-4bf1-9ee1-9ffeeb658b43
# ╠═25985a0a-1c9d-4c5e-8e80-b7ecf7138358
# ╠═ac645907-fe04-408d-ae90-8f6b02b1875b
# ╟─8078edad-6b02-40f6-9af2-161d4496daa1
# ╠═b1f28379-b038-4195-8b23-97fd5f207796
# ╠═174100db-2ec6-4023-8a8b-6d03f55a7df0
# ╠═c3174bbd-9235-4311-a52c-9aee4388efc7
# ╠═dcfc18ea-d388-4228-8f94-c031bc7ce415
# ╟─143bb099-0a68-4453-a147-8328e95923bf
# ╠═8af25f8b-5411-49c9-9f45-9b8d98fa2329
# ╠═23506d89-95fd-466b-90b1-0dec0c2a5555
# ╟─45ad8e08-691b-410c-bd26-e922f0019abf
# ╠═02514248-e707-4ee5-8813-bdb1bc732e54
# ╠═1606f0be-7b88-45a9-a787-5a7cbcc0c064
# ╟─af8c7676-129e-4628-a42b-b379754337ff
# ╠═ae7e03e1-7289-4ddb-b892-8cc3ac241594
# ╠═99309821-ed4a-42e1-a4fa-ef8670072377
# ╠═82e41123-3dbf-43b9-b0f6-48b3673eae0b
# ╠═947cefcc-4b21-4646-bda1-64aa9f5ee5c9
# ╟─450cfeb3-a32f-4350-93f1-cea2b4d1ee13
# ╠═4a352522-0f5c-4f56-88ce-d8dd5a86c079
# ╠═66416e28-8cc2-4575-86cd-2c5cffa9d32b
# ╟─0be5e706-3e73-4467-be3e-a8d46468e277
# ╠═b5002109-9034-4455-831a-7ddb9dc53dc8
# ╟─c7d3e7a9-3b68-4851-8d55-75f018cee2c4
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
