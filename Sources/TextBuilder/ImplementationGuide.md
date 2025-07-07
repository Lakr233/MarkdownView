## 1. 主题（Theme）相关

- **MarkdownTheme**：包含字体、颜色、间距、表格等样式配置，所有 transformer 都应依赖 theme 渲染。
    - `fonts`：正文、代码、粗体、斜体、标题等 UIFont。
    - `colors`：正文、强调、代码、代码背景等 UIColor。
    - `spacings`：段落、列表、单元格等 CGFloat。
    - `table`：表格圆角、边框、背景色等。
- **字体缩放**：`MarkdownTheme.FontScale` 支持字体缩放，`scaleFont(by:)`、`align(to:)` 可调整字体大小。

---

## 2. Transformer 相关

- **NodeTransformer 协议**：每种 AST 节点类型都要有一个实现该协议的 transformer。
    ```swift
    protocol NodeTransformer {
        func transform(_ input: NodeWrapper, theme: MarkdownTheme) -> NSAttributedString
    }
    ```
- **NodeWrapper**：AST 节点的包装类型，包含所有 markdown 语法节点。
    - 每个 NodeWrapper 有 `.transformer` 属性，自动分发到对应 transformer。
    - 提供了 `createDefaultAttributedString`、`createDefaultAttributes`、`createDefaultParagraphStyle`、`createDefaultAttachment` 等辅助方法。

---

## 3. AST 相关

- **AST 结构**：通过 markdown_core_ast 提供的 Root/NodeWrapper 结构体。
    - `Root` 有 `children`，每个 child 是 NodeWrapper。
    - 每个 NodeWrapper 代表一种 markdown 语法节点（如 text、heading、list、code、image 等）。
- **解析**：`TextBuilder.parse(_:)` 负责将 markdown 文本转为 AST。

---

## 4. 构建流程

- **TextBuilder**：负责整体流程。
    - `build(_:)`：遍历 AST，依次调用每个节点的 transformer，拼接结果。
    - 每个 transformer 负责将自己的节点及子节点递归转换为 NSAttributedString。

---

## 5. 富文本相关

- **NSAttributedString/NSMutableAttributedString**：用于富文本拼接。
    - 常用属性：`.font`、`.foregroundColor`、`.paragraphStyle`。
    - 可以通过 `NSMutableAttributedString(attachment:)` 插入附件（如图片、视图）。
- **TextAttachment/TextAttachedViewProvider**：用于插入自定义 UIView（如公式、图片等）。
    - `TextAttachment` 继承自 NSTextAttachment，持有 viewProvider。
    - `TextAttachedViewProvider` 协议定义了如何创建/复用/configure 视图。

---

## 6. 视图相关

- **TextView**：自定义 UITextView，支持插入 UIView 作为附件。
    - 通过 TextBehavior 管理 attachment 的布局和复用。
    - 只需关注 transformer 如何生成带附件的 NSAttributedString。

---

## 7. 代码高亮

- **Splash**：用于代码高亮，MarkdownTheme+Code.swift 提供了 codeTheme。
    - 代码块/行内代码 transformer 可用 Splash 生成高亮 NSAttributedString。

---

## 8. 常用辅助

- `NodeWrapper.createDefaultAttributedString(text:theme:)`：快速生成带默认样式的文本。
- `NodeWrapper.createDefaultAttributes(theme:)`：获取默认属性字典。
- `NodeWrapper.createDefaultParagraphStyle(theme:)`：获取默认段落样式。
- `NodeWrapper.createDefaultAttachment(usingViewProvider:theme:)`：生成带自定义视图的附件。

---

## 9. 其他注意事项

- transformer 需递归处理子节点，拼接结果。
- 需根据节点类型设置不同的字体、颜色、段落样式等。
- 代码块、图片、公式等节点需用 TextAttachment 或自定义 viewProvider。
- 需考虑段落间距、列表缩进、表格样式等细节。

