# vastR 0.6.34

- 支持列索引：`vast_build_index` / `vast_attach_index` / `vast_detach_index`
- 支持全文件排序：`vast_sort`，以及 `arrange.vast_tbl`
- `dplyr` 风格 `filter` / `select` / `arrange` / `distinct`
- 自动发现沙盒 Container 与经典路径下的 `api.json`
- 相对索引路径解析到数据文件同目录
- 空 body 的 detach 请求使用 `{}`，避免误发 `[]`

# vastR 0.6.2+

- 初版：`vast_open`、导出切片、`vast_find` / `vast_goto` / `vast_layout`
