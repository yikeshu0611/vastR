# vastR

**Author:** ZhangJing \<zj391120@163.com\>

Drive the macOS **Vast** large-file viewer from R / RStudio via a localhost JSON API.

Requires **Vast.app** at `/Applications/Vast.app` (app version ≥ 0.6.2 recommended).

## Install

### From GitHub (recommended)

```r
# install.packages("remotes")
remotes::install_github("yikeshu0611/vastR")
```

### From a Release asset

1. Open [Releases](https://github.com/yikeshu0611/vastR/releases)
2. Download `vastR-x.y.z.zip` from Assets
3. Install locally:

```r
install.packages("~/Downloads/vastR-0.6.34.zip", repos = NULL, type = "source")
# or, if unzipped to a folder:
# install.packages("~/Downloads/vastR", repos = NULL, type = "source")
```

## Quick start

```r
library(vastR)
library(dplyr)

# Open a large file (does not load the whole table into memory)
t <- vast_open("~/data/huge.csv", delim = ",", header = 1)

# Preview
head(t)

# Filter (can use a column index when attached)
t %>% filter(itemid == "2257526")

# Sort (returns a new vast_tbl / writes a TSV)
t %>% arrange(desc(charttime))
# or
vast_sort(t, "charttime", order = "desc", max_rows = 1000)

# Column index
idx <- vast_build_index(t, "itemid", path = "itemid.vidx")
t <- vast_attach_index(t, "itemid", path = idx)
# … filter / sort prefer the index when available
vast_detach_index(t)

# Other
vast_status()
vast_goto(100000)
vast_find("ERROR")
vast_is_running()
```

Send an in-memory data.frame to Vast:

```r
vast_view(mtcars)
```

## Main functions

| Function | Purpose |
|----------|---------|
| `vast_open` / `vast_view` | Open a file or data.frame |
| `filter` / `select` / `arrange` | dplyr-style verbs (run in Vast) |
| `vast_filter` / `vast_sort` | Explicit filter / sort |
| `vast_build_index` / `vast_attach_index` / `vast_detach_index` | Column unique-value index |
| `vast_read` / `vast_export` | Export a line range, then read it |
| `vast_layout` / `vast_goto` / `vast_find` / `vast_status` | Layout and navigation |

## Notes

- While Vast is running it writes `~/Library/Application Support/com.zhangjing.Vast/api.json` (or under the Mac App Store container). `vastR` discovers both paths.
- On the sandboxed build, the first API open of a file outside the sandbox may ask you to pick the file once in Vast.

## License

MIT
