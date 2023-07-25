### A Pluto.jl notebook ###
# v0.19.27

using Markdown
using InteractiveUtils

# ╔═╡ 0e45710f-022a-4ee5-9573-d6875e36513c
using CSV, DataFrames, Arrow

# ╔═╡ b3edc3d9-e689-451e-9e60-a9ccf541c438
using Statistics

# ╔═╡ 289604d1-b5f3-4f82-a26f-b7d84a3da33c
using Dates

# ╔═╡ 338b626a-28ac-11ee-2eb7-07e12d2085dd
md"""# _Working with DataFrames.jl beyond CSV_
### Jacob Quinn
"""

# ╔═╡ 1845587a-cdcd-462a-8266-11b9e12acb9d
md"""# Part 5: _Data Ingestion via Arrow.jl_


#### Arrow Primer

###### The arrow data format specifies memory layouts for typed, structured data, with the aim of providing an efficient, zero-copy ability to share data between processes and beyond. The file and IPC flavors contain metadata in the flatbuffer format about the data types, column byte offsets, etc. The file format provides the metadata in a way that allows random access to all data, whereas the IPC format supports streaming batches of data. The C data interface has the same _data_ layout, but uses a text-based metadata.


#### Getting Started With Arrow

So how do get our data into the arrow format? Remembering the Tables.jl interface from part 4, the Arrow.jl packages provides the `Arrow.write` "sink" function that allows taking any valid "table source" and writing it to the arrow format. So using the data we worked with in part 4:
"""
# * Arrow.write
#   * writing w/ partitions
#   * append
#   * column types
#   * file vs. IPC
# * Arrow.Table
# * Arrow.Stream
# * metadata
# * Future: C data interface

# As one of the most common data formats, let's discuss briefly the various ways the CSV.jl package helps process CSV data:
# \

# ╔═╡ 248445d5-16f5-4475-b8ad-f20e64ad5b19
md"""
Data downloaded from [here](https://drive.google.com/file/d/1LJ5ftwOJbJtXVjDjWa3btuDPTYpAcGbh/view?usp=sharing) (NOTE: this is a gzipped file around ~350MB, 1GB uncompressed!). Alternatively, a much smaller subset of the data can be downloaded [here](https://drive.google.com/file/d/1Lde1DZwBHmomm9TOg5L4kP-vPNkymSNP/view?usp=sharing). To make subsequent commands work, edit the following cell to point to the path of whichever file you downloaded.
"""

# ╔═╡ 0b4a529f-7f66-4882-be24-4cd03122b529
const path = "/Users/quinnj/randoms.csv.gz"

# ╔═╡ 1f4201a9-b4f1-483a-b3ab-da99ba34fecb
df = CSV.read(path, DataFrame; header=["id", "Fname", "Lname", "Salary", "Wage", "StartDate", "TermDate"])

# ╔═╡ ac8534e9-46cf-4cd1-bab7-e41bcd996517
arrow_bytes = take!(Arrow.write(IOBuffer(), df))

# ╔═╡ 168cb6e4-5dab-492c-a479-7e1d79e35396
md"""
What exactly are we doing here? Let's take it step-by-step:
  * First we read in the dataset via CSV directly into a materialized DataFrame
  * Then we call `Arrow.write`, passing an `IOBuffer` as the first argument
  * `IOBuffer` is an in-memory buffered `IO` object
  * We pass our `DataFrame` `df` as the 2nd argument
  * Once the `DataFrame` is written to our `IOBuffer`, we `take` the final bytes that were written, so we get a `Vector{UInt8}` returned

These bytes are now officially "arrow data"; that is, we could pass them to python, go, Java, C++, pyarrow, etc. and be able to read and process the data.

But what can we do with these bytes in _Julia_?
"""

# ╔═╡ f119a8f3-5311-4602-a311-d86db7b62021
table = Arrow.Table(arrow_bytes)

# ╔═╡ e9bb57ed-04cd-4869-9de7-e60e8c1e82fd
md"""
Ok, so what is this `Arrow.Table` thing? We can see it has 18M rows, 7 columns, and we can see the column names and types. We can also see that it only took 74ms to "read" this data! (Compared with > 1s above with `CSV.read`). So.....did we actually read the data??
"""

# ╔═╡ fc266218-2760-4036-b2ec-50bccaeef7e9
(table.id, table.Fname, table.Wage)

# ╔═╡ a3145793-4800-4689-bf48-6575945f5b23
md"""
Sure enough! Oh but wait, it looks like when I say `table.id` I'm not getting back a `Vector{Int}`, but this `Arrow.Primitive{Int64, Vector{Int64}}` thing. What's that? Let's quickly walk through what's going on when we call `Arrow.Table`, and that should help understand what `Arrow.Primitive` (and `Arrow.List`) is and why it's important. So, when you call `Arrow.Table`, here's what happens under the hood in 74ms.

1. Validate the bytes actually contain arrow data (checking for "magic" byte markers)
2. Parse the "schema" message; arrow data is split into "messages", with the 2 primary message types being "schema" or "data". The schema message tells us what kind of data to expect in subsequent messages (column names, types, etc.)
3. Parse data messages, which note the expected # of rows, byte offsets of each column, whether compression was used, etc.
4. Build custom Arrow.jl column "views" into data message bytes

Aha! So `Arrow.Primitive{Int64}` is really just like a `Vector{Int64}`, except immutable, and really a "view" into `Int64` values layed out next to each other at a specific byte offset in arrow formattted memory!

This also helps explain why "reading" arrow data is so fast: there's no text parsing or allocating, we're really just reinterpretting bytes, first as flatbuffer metadata, then creating view structs of the expected column types at specific byte offsets in the memory.

And remember, that's one of the primary aims of the format: allowing super efficient data reading with as little need to allocate/copy as possible.

Ok, that's great, but can I use arrow data in a DataFrame?
"""

# ╔═╡ 0b900838-a050-4cb5-9860-27d7961ca861
arrow_df = DataFrame(table)

# ╔═╡ e3568b49-fe39-4fad-a65a-c8256fc852c3
md"""
Ok, but what's going on here? _Now_ is a copy being made?
"""

# ╔═╡ 9d4bb894-d0fc-424e-a8f0-a8137f5300a2
table.id === arrow_df.id

# ╔═╡ 0a201249-ffd4-4dc9-81e0-1799fb6b4d47
arrow_df.id

# ╔═╡ 2f5cca18-c648-4d82-bac3-cf801e154e97
md"""
Ah...so no copy is being made. We're using these "arrow column views" directly as columns in our `DataFrame`. But we can still do pretty normal operations, right?
"""

# ╔═╡ 781214ac-2518-40b7-b290-ac9e609ce09e
avg_wage_col = mean(skipmissing(arrow_df.Wage))

# ╔═╡ 9a01ba16-1725-4533-88e8-f9d7d8dfa215
arrow_df[1, 2] = "different name"

# ╔═╡ d6e184bd-0f80-440b-b1f6-bd03bd51d192
md"""
Ah, here we see the "immutable" part of arrow data. Specifically, strings in arrow have a unique layout: an entire column's string bytes are laid out end-to-end in a long byte vector, with another vector of "offsets" where each element is the position within the byte vector. With this understanding, it makes sense that `setindex!` wouldn't work on an `Arrow.List` column, since it would be expensive to change/shuffle bytes in the middle of the long byte vector.

###### Switching Gears

Ok, let's highlight a few other cool things about the arrow data format, specifically the batch/streaming abilities. So we saw that we can write a table source into the arrow format, but arrow also has an underlying concept of "record batches". Remember back to the arrow deserialization process: we actually read data when data "messages" are processed. And that doesn't have to just be a _single_ data message, there can be many! And we can control this when writing, like:
"""

# ╔═╡ 71ca78a3-2355-4e52-9d4f-8c845e10c416
arrow_bytes2 = take!(Arrow.write(IOBuffer(), Iterators.partition(df, 1_000_000)))

# ╔═╡ 27c09d41-a5ad-4569-b626-c7f2b559bd1a
table2 = Arrow.Table(arrow_bytes2)

# ╔═╡ 379cce7e-b6c2-430f-84f6-07ceba76bfeb
table2.id

# ╔═╡ d523a96c-02d6-4baf-906e-981f1200a3ef
md"""
Ok, let's walk through what's going on here:

1. We're writing the same `DataFrame` as before into the arrow format, but this time we're using `Iterators.partition` to process 1M rows at a time
2. We're then reading those arrow bytes into an `Arrow.Table` again
3. _BUT_, instead of getting an `Arrow.Primitive` as our column for `id`, we're now seeing this `ChainedVector{Int, Arrow.Primitive}` thing

So what's a `ChainedVector`? It's a utility array that takes any number of similarly typed arrays, and "chains" them together as a single, flattened array. And in this case, we can take a peak under the hood:
"""

# ╔═╡ 2afee93a-6bf6-4698-b66f-e75ebb929575
table2.id.arrays

# ╔═╡ 56efc9b5-7d5a-4698-91f6-5d6b9a12cc64
md"""
Ah! There's our `Arrow.Primitive` arrays. There are 18 of them, one `Arrow.Primitive` for each partition that we wrote out in our arrow data. But we can still process these chained vectors just like normal arrays:
"""

# ╔═╡ 42e0db1d-1e53-4aa0-b619-606f13f2ccf7
avg_wage_col2 = mean(skipmissing(table2.Wage))

# ╔═╡ 88b3897c-f636-4fec-b757-de4e6f629915
md"""
So this `ChainedVector` thing is nice, but what if I didn't want to materialize all data messages at once? Enter `Arrow.Stream`.
"""

# ╔═╡ 3c959658-2de4-427b-8a6f-b07778aedb14
stream = Arrow.Stream(arrow_bytes2)

# ╔═╡ 95943312-a30b-4bba-b303-b84c7b1cdabe
md"""
Ok, so what can I do with this stream thing? An `Arrow.Stream` provides an _iterator_ over data messages. It does the initial schema message processing, then returns, and for each call to `iterate`, returns an `Arrow.Table` for a single data message. So we can accomplish our wage averaging as before:
"""

# ╔═╡ c97219a6-c57b-4872-a12b-9df2592894de
avg_wage3 = begin
	sum_wage = 0.0
	count = 0
	for table in stream
		sum_wage += sum(skipmissing(table.Wage))
		count += length(table.Wage)
	end
	sum_wage / count
end

# ╔═╡ cbec4476-bf55-41df-bac1-18a37f07b237
md"""
Ok, so we glossed over this a bit earlier when we said to call `Arrow.write` with `Iterators.partition` to write multiple data messages, but the actual mechanic at play here is another Tables.jl interface: `Tables.partitions`. This interface function provides a way for table sources to express that they can be _partitioned_ into multiple batches of valid "table sources". Table sources may or may not actually support partitioning naturally, so by default `Tables.partitions` just returns a single iteration of the table itself. But when supported, a table can "split" itself into natural partitions. In our example above, `Iterators.partition` is treated as a default partitioned table and so works conveniently on `DataFrame`s.

###### Custom Types

Let's show one more unique thing about the arrow format.
"""

# ╔═╡ ef4ccf3d-0401-418a-882d-c62d77e1099c
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

# ╔═╡ f23b0579-926a-4d8d-a32a-52fb9ace9676
persons = [Person(row.id, row.Fname, row.Lname, row.Salary, row.Wage, row.StartDate, row.TermDate) for row in eachrow(df)]

# ╔═╡ 01914b41-a348-4681-bf46-27c7bf54d608
dfp = DataFrame(persons=persons)

# ╔═╡ 5f0f45d8-0876-430a-83ca-9796040e4398
arrow_bytes3 = take!(Arrow.write(IOBuffer(), dfp))

# ╔═╡ 43909eba-7eaf-4497-9165-2c0a66b1de9e
table3 = Arrow.Table(arrow_bytes3; convert=false)

# ╔═╡ c4f28fc8-96fe-4a9c-a138-8886c8373ca7
Arrow.ArrowTypes.arrowname(::Type{Person}) = :Person

# ╔═╡ b39f6b4a-6239-4d62-9df0-fefdcc79a9a2
Arrow.ArrowTypes.JuliaType(::Val{:Person}, S, met) = Person

# ╔═╡ ef92b24a-b711-4a7a-b880-d06ce31049d8
arrow_bytes4 = take!(Arrow.write(IOBuffer(), dfp))

# ╔═╡ bf6a0cca-42c0-488a-9e29-de6fd0ae9b70
table4 = Arrow.Table(arrow_bytes4)

# ╔═╡ 3ec7a2c4-f95f-4aa2-ac20-817a76ad9bb8
table4.persons

# ╔═╡ 14911250-f08c-40c7-9ddd-4a9aa8425ce7
table4.persons[1]

# ╔═╡ 8f11a33d-1e2b-4c0d-9caa-f9660784902d
md"""
Ok, a lot going on here, but let's walk through it:

1. We defined a custom struct `Person` that models a single person entity
2. We created a `DataFrame` that has a single column `persons`, for all our person entities
3. We wrote this out to arrow, then read it back in, but got a `NamedTuple` of the individual fields instead of the `Person` struct; this is because `Arrow.write` tries to be as compatible with other language implementations when possible, and thus uses a generic "struct" representation
4. We then overloaded 2 `Arrow.ArrowTypes` functions to signal that our `Person` structs should be written with additional metadata that will allow them to be deserialized as proper structs
5. We then write and read the persons `DataFrame` again, now that the overloads are in place, and see that we indeed get instances of our `Person` struct when indexing the single arrow column

#### Other Arrow.jl Features

* `Arrow.append` that allows adding _additional_ data messages to existing IPC arrow streams
* Table and column metadata; using the `metadata` and `colmetadata` interfaces to get metadata for the arrow table or for individual columns

#### Future of Arrow.jl

* Keeping up with specification changes/enhancements (alternative layouts, encodings, etc.)
* Finish support for the C data/stream interfaces
* Native support for Arrow flight (arrow data over gRPC)
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Arrow = "69666777-d1a9-59fb-9406-91d4454c9d45"
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Dates = "ade2ca70-3891-5945-98fb-dc099432e06a"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[compat]
Arrow = "~2.6.2"
CSV = "~0.10.11"
DataFrames = "~1.6.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.0-rc1"
manifest_format = "2.0"
project_hash = "fb57216226440ef98380e41f904918617973ecc2"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Arrow]]
deps = ["ArrowTypes", "BitIntegers", "CodecLz4", "CodecZstd", "ConcurrentUtilities", "DataAPI", "Dates", "EnumX", "LoggingExtras", "Mmap", "PooledArrays", "SentinelArrays", "Tables", "TimeZones", "TranscodingStreams", "UUIDs"]
git-tree-sha1 = "954666e252835c4cf8819ce4ffaf31073c1b7233"
uuid = "69666777-d1a9-59fb-9406-91d4454c9d45"
version = "2.6.2"

[[deps.ArrowTypes]]
deps = ["Sockets", "UUIDs"]
git-tree-sha1 = "8c37bfdf1b689c6677bbfc8986968fe641f6a299"
uuid = "31f734f8-188a-4ce0-8406-c8a06bd891cd"
version = "2.2.2"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BitIntegers]]
deps = ["Random"]
git-tree-sha1 = "abb894fb55122b4604af0d460d3018e687a60963"
uuid = "c3b6d118-76ef-56ca-8cc7-ebb389d030a1"
version = "0.3.0"

[[deps.CEnum]]
git-tree-sha1 = "eb4cb44a499229b3b8426dcfb5dd85333951ff90"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.4.2"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "PrecompileTools", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "44dbf560808d49041989b8a96cae4cffbeb7966a"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.11"

[[deps.CodecLz4]]
deps = ["Lz4_jll", "TranscodingStreams"]
git-tree-sha1 = "59fe0cb37784288d6b9f1baebddbf75457395d40"
uuid = "5ba52731-8f18-5e0d-9241-30f10d1ec561"
version = "0.4.0"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "02aa26a4cf76381be7f66e020a3eddeb27b0a092"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.2"

[[deps.CodecZstd]]
deps = ["CEnum", "TranscodingStreams", "Zstd_jll"]
git-tree-sha1 = "849470b337d0fa8449c21061de922386f32949d9"
uuid = "6b39b394-51ab-5f42-8807-6242bab2b4c2"
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

[[deps.ConcurrentUtilities]]
deps = ["Serialization", "Sockets"]
git-tree-sha1 = "5372dbbf8f0bdb8c700db5367132925c0771ef7e"
uuid = "f0e56b4a-5159-44fe-b623-3e5288b988bb"
version = "2.2.1"

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

[[deps.EnumX]]
git-tree-sha1 = "bdb1942cd4c45e3c678fd11569d5cccd80976237"
uuid = "4e289a0a-7415-4d19-859d-a7e5c4648b56"
version = "1.0.4"

[[deps.ExprTools]]
git-tree-sha1 = "c1d06d129da9f55715c6c212866f5b1bddc5fa00"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.9"

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

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

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

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "cedb76b37bc5a6c702ade66be44f831fa23c681e"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.0.0"

[[deps.Lz4_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "5d494bc6e85c4c9b626ee0cab05daa4085486ab1"
uuid = "5ced341a-0733-55b8-9ab6-a4889d929147"
version = "1.9.3+0"

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

[[deps.Mocking]]
deps = ["Compat", "ExprTools"]
git-tree-sha1 = "4cc0c5a83933648b615c36c2b956d94fda70641e"
uuid = "78c3b35d-d492-501b-9361-3d52fe80e533"
version = "0.7.7"

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

[[deps.RecipesBase]]
deps = ["PrecompileTools"]
git-tree-sha1 = "5c3d09cc4f31f5fc6af001c250bf1278733100ff"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.4"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "30449ee12237627992a99d5e30ae63e4d78cd24a"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.2.0"

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

[[deps.TimeZones]]
deps = ["Dates", "Downloads", "InlineStrings", "LazyArtifacts", "Mocking", "Printf", "RecipesBase", "Scratch", "Unicode"]
git-tree-sha1 = "cdaa0c2a4449724aded839550eca7d7240bb6938"
uuid = "f269a46b-ccf7-5d73-abea-4c690281aa53"
version = "1.10.0"

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

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "49ce682769cd5de6c72dcf1b94ed7790cd08974c"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.5+0"

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
# ╟─338b626a-28ac-11ee-2eb7-07e12d2085dd
# ╟─1845587a-cdcd-462a-8266-11b9e12acb9d
# ╠═0e45710f-022a-4ee5-9573-d6875e36513c
# ╟─248445d5-16f5-4475-b8ad-f20e64ad5b19
# ╠═0b4a529f-7f66-4882-be24-4cd03122b529
# ╠═1f4201a9-b4f1-483a-b3ab-da99ba34fecb
# ╠═ac8534e9-46cf-4cd1-bab7-e41bcd996517
# ╟─168cb6e4-5dab-492c-a479-7e1d79e35396
# ╠═f119a8f3-5311-4602-a311-d86db7b62021
# ╟─e9bb57ed-04cd-4869-9de7-e60e8c1e82fd
# ╠═fc266218-2760-4036-b2ec-50bccaeef7e9
# ╟─a3145793-4800-4689-bf48-6575945f5b23
# ╠═0b900838-a050-4cb5-9860-27d7961ca861
# ╟─e3568b49-fe39-4fad-a65a-c8256fc852c3
# ╠═9d4bb894-d0fc-424e-a8f0-a8137f5300a2
# ╠═0a201249-ffd4-4dc9-81e0-1799fb6b4d47
# ╟─2f5cca18-c648-4d82-bac3-cf801e154e97
# ╠═b3edc3d9-e689-451e-9e60-a9ccf541c438
# ╠═781214ac-2518-40b7-b290-ac9e609ce09e
# ╠═9a01ba16-1725-4533-88e8-f9d7d8dfa215
# ╟─d6e184bd-0f80-440b-b1f6-bd03bd51d192
# ╠═71ca78a3-2355-4e52-9d4f-8c845e10c416
# ╠═27c09d41-a5ad-4569-b626-c7f2b559bd1a
# ╠═379cce7e-b6c2-430f-84f6-07ceba76bfeb
# ╟─d523a96c-02d6-4baf-906e-981f1200a3ef
# ╠═2afee93a-6bf6-4698-b66f-e75ebb929575
# ╟─56efc9b5-7d5a-4698-91f6-5d6b9a12cc64
# ╠═42e0db1d-1e53-4aa0-b619-606f13f2ccf7
# ╟─88b3897c-f636-4fec-b757-de4e6f629915
# ╠═3c959658-2de4-427b-8a6f-b07778aedb14
# ╟─95943312-a30b-4bba-b303-b84c7b1cdabe
# ╠═c97219a6-c57b-4872-a12b-9df2592894de
# ╟─cbec4476-bf55-41df-bac1-18a37f07b237
# ╠═289604d1-b5f3-4f82-a26f-b7d84a3da33c
# ╠═ef4ccf3d-0401-418a-882d-c62d77e1099c
# ╠═f23b0579-926a-4d8d-a32a-52fb9ace9676
# ╠═01914b41-a348-4681-bf46-27c7bf54d608
# ╠═5f0f45d8-0876-430a-83ca-9796040e4398
# ╠═43909eba-7eaf-4497-9165-2c0a66b1de9e
# ╠═c4f28fc8-96fe-4a9c-a138-8886c8373ca7
# ╠═b39f6b4a-6239-4d62-9df0-fefdcc79a9a2
# ╠═ef92b24a-b711-4a7a-b880-d06ce31049d8
# ╠═bf6a0cca-42c0-488a-9e29-de6fd0ae9b70
# ╠═3ec7a2c4-f95f-4aa2-ac20-817a76ad9bb8
# ╠═14911250-f08c-40c7-9ddd-4a9aa8425ce7
# ╟─8f11a33d-1e2b-4c0d-9caa-f9660784902d
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
