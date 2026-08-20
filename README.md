# vastR

在 R / RStudio 中驱动 macOS 大文件阅读器 **[Vast](https://github.com/yikeshu0611)**（通过本机 localhost JSON API）。

需要已安装 **Vast.app** 到 `/Applications/Vast.app`（版本建议 ≥ 0.6.2）。

## 安装

### 从 GitHub（推荐）

```r
# install.packages("remotes")
remotes::install_github("yikeshu0611/vastR")
```

### 从 Release 资源包

1. 打开 [Releases](https://github.com/yikeshu0611/vastR/releases)
2. 下载 `vastR-x.y.z.zip`（Assets）
3. 本地安装：

```r
install.packages("~/Downloads/vastR-0.6.34.zip", repos = NULL, type = "source")
# 若解压成文件夹：
# install.packages("~/Downloads/vastR", repos = NULL, type = "source")
```

## 快速开始

```r
library(vastR)
library(dplyr)

# 打开大文件（不会整表读进内存）
t <- vast_open("~/data/huge.csv", delim = ",", header = 1)

# 预览
head(t)

# 筛选（可走列索引加速）
t %>% filter(itemid == "2257526")

# 排序（返回新的 vast_tbl / 写出 TSV）
t %>% arrange(desc(charttime))
# 或
vast_sort(t, "charttime", order = "desc", max_rows = 1000)

# 列索引
idx <- vast_build_index(t, "itemid", path = "itemid.vidx")
t <- vast_attach_index(t, "itemid", path = idx)
# … filter / sort 会优先用索引
vast_detach_index(t)

# 其它
vast_status()
vast_goto(100000)
vast_find("ERROR")
vast_is_running()
```

把内存里的 data.frame 丢进 Vast 看：

```r
vast_view(mtcars)
```

## 主要函数

| 函数 | 作用 |
|------|------|
| `vast_open` / `vast_view` | 打开文件或 data.frame |
| `filter` / `select` / `arrange` | dplyr 风格（在 Vast 侧扫文件） |
| `vast_filter` / `vast_sort` | 显式筛选 / 排序 |
| `vast_build_index` / `vast_attach_index` / `vast_detach_index` | 列唯一值索引 |
| `vast_read` / `vast_export` | 导出行片段到本地再读入 |
| `vast_layout` / `vast_goto` / `vast_find` / `vast_status` | 布局与导航 |

## 说明

- Vast 运行时会写 `~/Library/Application Support/com.qo.vast/api.json`（Mac App Store 沙盒版则在 Container 路径下）。`vastR` 会自动查找。
- 沙盒版首次用 API 打开沙盒外文件时，可能需要在 Vast 里点选授权一次。

## 许可证

MIT
