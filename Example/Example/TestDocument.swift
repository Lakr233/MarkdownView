//
//  TestDocument.swift
//  Example
//
//  Created by 秋星桥 on 6/29/25.
//

import Foundation

let testDocument = ###"""
好的，这是一个非常重要且经常被问到的问题！

在 iOS 13 及更高版本中，`SceneDelegate` 不需要像 `AppDelegate` 那样显式地“注册”给 `App`。相反，系统通过 `Info.plist` 文件中的配置自动发现并使用 `SceneDelegate`。

---

### 通过 `Info.plist` 注册 `SceneDelegate`

当你创建一个新的 iOS 项目时，Xcode 会自动为你在 `Info.plist` 中添加必要的配置。这个配置告诉系统你的应用程序支持场景 (Scenes)，并且哪个类是你的 `SceneDelegate`。

主要涉及以下两个键：

1.  **`Application Scene Manifest` (`UISceneConfigurations`)**: 这是场景配置的根键。
2.  **`Scene Configuration` (`UISceneSessionRoleApplication`)**: 在 `Application Scene Manifest` 下，这个键指定了应用程序的场景角色。
3.  **`Delegate Class Name` (`UISceneDelegateClassName`)**: 在 `Scene Configuration` 下，这个键用于指定哪个类是该场景角色的委托（即你的 `SceneDelegate` 类名）。

---

#### 步骤和具体配置

1.  **打开你的 `Info.plist` 文件。** 你可以在项目导航器中找到它。
2.  **查找或添加 `Application Scene Manifest`。**
    *   在 `Info.plist` 中，右键点击空白处，选择 `Add Row`。
    *   输入 `Application Scene Manifest`，并将其类型设置为 `Dictionary`。
3.  **在 `Application Scene Manifest` 下添加 `Scene Configuration`。**
    *   在 `Application Scene Manifest` 下，点击旁边的 `+` 号。
    *   输入 `Scene Configuration`，并将其类型设置为 `Array`。
4.  **在 `Scene Configuration` 数组中添加一个 `Item 0` (Dictionary)。**
    *   这代表一个场景配置。
5.  **在 `Item 0` 下添加以下键值对：**
    *   **`Application Session Role` (`UISceneSessionRole`)**:
        *   **类型**: `String`
        *   **值**: `UIWindowSceneSessionRoleApplication` (这是默认的应用程序窗口场景角色)
    *   **`Delegate Class Name` (`UISceneDelegateClassName`)**:
        *   **类型**: `String`
        *   **值**: `$(PRODUCT_MODULE_NAME).SceneDelegate` 或直接 `SceneDelegate`
            *   `$(PRODUCT_MODULE_NAME)` 是一个占位符，它会在编译时替换为你的项目名称（即模块名称）。这是推荐的做法，因为它更灵活。
            *   如果你不使用 Swift 的命名空间，也可以直接写 `SceneDelegate`。
    *   **`Storyboard Name` (`UISceneStoryboardFile`) (可选)**:
        *   **类型**: `String`
        *   **值**: 你的主 Storyboard 文件名 (例如 `Main`)。
        *   如果你不使用 Storyboard，而是完全通过代码设置 UI，那么这个键可以省略。

---

#### 示例 `Info.plist` 结构 (XML 格式)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <false/> // 或者 true，取决于你是否支持多场景
        <key>UISceneConfigurations</key>
        <dict>
            <key>UIWindowSceneSessionRoleApplication</key>
            <array>
                <dict>
                    <key>UISceneConfigurationName</key>
                    <string>Default Configuration</string>
                    <key>UISceneDelegateClassName</key>
                    <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string> // 这里是关键
                    <key>UISceneStoryboardFile</key>
                    <string>Main</string> // 如果你使用 Storyboard
                </dict>
            </array>
        </dict>
    </dict>
    <!-- 其他 Info.plist 内容 -->
</dict>
</plist>
```

---

#### 总结

你不需要在代码中手动调用任何方法来“注册” `SceneDelegate`。系统会在应用启动时读取 `Info.plist` 中的 `Application Scene Manifest` 配置，并根据 `UISceneDelegateClassName` 键中指定的名字来实例化和管理你的 `SceneDelegate`。

你提供的初始代码中：

```swift
let delegate = AppDelegate()
UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    NSStringFromClass(Application.self),
    NSStringFromClass(AppDelegate.self)
)
```

`UIApplicationMain` 函数会负责应用程序的启动过程，它会读取 `Info.plist` 并初始化 `AppDelegate` 和 `SceneDelegate`。

所以，确保你的 `Info.plist` 配置正确即可。

假设我们找到了 \\(k\\) 个满足条件的平面。设这些平面的方程为：
\\[ L_j(x, y, z) = a_j x + b_j y + c_j z - d_j = 0 \quad \text{for } j = 1, \dots, k \\]
根据题意，原点 \\((0,0,0)\\) 不在任何一个平面上，这意味着 \\(L_j(0,0,0) = -d_j \neq 0\\)，所以 \\(d_j \neq 0\\) 对所有 \\(j\\) 成立。

---
现在，我们构造一个多项式 \\(P(x,y,z)\\) 如下：
\\[ P(x, y, z) = \prod_{j=1}^{k} L_j(x, y, z) \\]
这个多项式的次数 \\(\deg(P) = k\\)。

---

好的，没问题！这是一个简单的表格，包含一些示例数据。你可以告诉我你想要什么样的数据，或者表格有什么特定用途，我帮你画一个更合适的。

| 姓名   | 年龄 | 城市     | 职业   |
|--------|------|----------|--------|
| 张三   | 28   | 北京     | 工程师 |
| 李四   | 35   | 上海     | 医生   |
| 王五   | 22   | 广州     | 学生   |
| 赵六   | 40   | 深圳     | 教师   |

哈哈哈，没问题！做不出来太正常了，刚开始学方程都这样。别灰心，解方程就像玩一个新游戏，需要先知道规则，多练几次就找到感觉了！

我来带你一步一步地解这些题，让你看看是怎么回事。

---

### 一、 简单方程填空题（答案与解析）

解这些题的秘诀是 **“等式的性质”**，就像一个天平，为了保持平衡，左边做什么，右边也要做什么。

1.  \\( x + 5 = 12 \\)
    *   **思路**：为了让左边只剩下 \\(x\\)，我们需要把 "+5" 去掉。去掉 "+5" 的方法就是减去5。
    *   **解**：等式左边 \\(x+5-5\\)，右边也要跟着 \\(12-5\\)。所以 \\(x = 7\\)。
    *   **答案**：\\( x = \underline{7} \\)

2.  \\( y - 3 = 10 \\)
    *   **思路**：为了让左边只剩下 \\(y\\)，我们需要把 "-3" 去掉。去掉 "-3" 的方法就是加上3。
    *   **解**：等式左边 \\(y-3+3\\)，右边也要跟着 \\(10+3\\)。所以 \\(y = 13\\)。
    *   **答案**：\\( y = \underline{13} \\)

3.  \\( 2z = 18 \\)
    *   **思路**：\\(2z\\) 的意思是 \\(2 \times z\\)。为了让左边只剩下 \\(z\\)，我们需要把 "乘以2" 去掉。方法就是除以2。
    *   **解**：等式左边 \\(2z \div 2\\)，右边也要跟着 \\(18 \div 2\\)。所以 \\(z = 9\\)。
    *   **答案**：\\( z = \underline{9} \\)

4.  \\( \frac{a}{4} = 7 \\)
    *   **思路**：\\(\frac{a}{4}\\) 的意思是 \\(a \div 4\\)。为了让左边只剩下 \\(a\\)，我们需要把 "除以4" 去掉。方法就是乘以4。
    *   **解**：等式左边 \\(\frac{a}{4} \times 4\\)，右边也要跟着 \\(7 \times 4\\)。所以 \\(a = 28\\)。
    *   **答案**：\\( a = \underline{28} \\)

---

### 二、 列方程解决问题（答案与解析）

做应用题的关键是：**找到题目里的等量关系，也就是什么等于什么**。

1.  **铅笔有多少支？**
    *   **等量关系**：小红的铅笔数 = 小亮的铅笔数 + 3。
    *   **列方程**：我们先算出小红有多少支笔：\\(15 \times 2 = 30\\) 支。设小亮有 \\(x\\) 支，那么方程就是：
        \\[ x + 3 = 30 \\]
    *   **解答**：\\(x = 30 - 3\\)，所以 \\(x = 27\\)。
    *   **答案**：小亮有 **27** 支铅笔。

2.  **果园里的苹果树和梨树**
    *   **等量关系**：梨树的数量 + 苹果树的数量 = 200。
    *   **列方程**：设梨树有 \\(x\\) 棵，那苹果树就是 \\((x + 20)\\) 棵。方程就是：
        \\[ x + (x + 20) = 200 \\]
    *   **解答**：\\(2x + 20 = 200\\)  ➡️  \\(2x = 200 - 20\\)  ➡️  \\(2x = 180\\)  ➡️  \\(x = 90\\)。
    *   **答案**：梨树有 **90** 棵，苹果树有 \\(90 + 20 = \textbf{110}\\) 棵。

3.  **小狗和小猫的体重**
    *   **等量关系**：小狗的体重 - 小猫的体重 = 8千克。
    *   **列方程**：设小猫重 \\(x\\) 千克，那小狗就重 \\(3x\\) 千克。方程就是：
        \\[ 3x - x = 8 \\]
    *   **解答**：\\(2x = 8\\)  ➡️  \\(x = 4\\)。
    *   **答案**：小猫重 **4** 千克，小狗重 \\(3 \times 4 = \textbf{12}\\) 千克。

4.  **买玩具**
    *   **等量关系**：玩具汽车的钱 + 玩具飞机的钱 = 100元。
    *   **列方程**：设玩具汽车 \\(x\\) 元，那玩具飞机就是 \\(4x\\) 元。方程就是：
        \\[ x + 4x = 100 \\]
    *   **解答**：\\(5x = 100\\)  ➡️  \\(x = 20\\)。
    *   **答案**：玩具汽车 **20** 元，玩具飞机 \\(4 \times 20 = \textbf{80}\\) 元。

5.  **三个连续的自然数**
    *   **等量关系**：第一个数 + 第二个数 + 第三个数 = 66。
    *   **列方程**：设最小的数是 \\(x\\)，那另外两个就是 \\((x+1)\\) 和 \\((x+2)\\)。方程就是：
        \\[ x + (x+1) + (x+2) = 66 \\]
    *   **解答**：\\(3x + 3 = 66\\)  ➡️  \\(3x = 66 - 3\\)  ➡️  \\(3x = 63\\)  ➡️  \\(x = 21\\)。
    *   **答案**：这三个数是 **21**、**22**、**23**。

---

### 三、 挑战题（答案与解析）

这两道题稍微拐了个弯，但原理一样！

1.  **班级人数**
    *   **等量关系**：这道题最关键！题目给了两个描述男生人数的方式，一个是“比女生多2人”，一个是“女生的 \\(\frac{5}{4}\\) 倍”。那这两个描述肯定是相等的！
    *   **列方程**：设女生有 \\(x\\) 人。那么男生人数可以表示为 \\((x+2)\\)，也可以表示为 \\(\frac{5}{4}x\\)。所以方程是：
        \\[ x + 2 = \frac{5}{4}x \\]
    *   **解答**：这个方程有分数，别怕！我们先把 \\(x\\) 移到一边：\\(2 = \frac{5}{4}x - x\\)。这里的 \\(x\\) 就是 \\(1x\\)，也就是 \\(\frac{4}{4}x\\)。所以 \\(2 = \frac{5}{4}x - \frac{4}{4}x\\)，也就是 \\(2 = \frac{1}{4}x\\)。一个数的四分之一是2，那这个数就是 \\(2 \times 4 = 8\\)。所以 \\(x=8\\)。
    *   **答案**：女生有 **8** 人，男生有 \\(8+2 = \textbf{10}\\) 人。

2.  **修路**
    *   这道题用方程有点绕，我们直接分步计算更简单！
    *   **第一步**：算第一天修了多少。\\(360 \times \frac{1}{3} = 120\\) 米。
    *   **第二步**：算修完第一天还剩多少。\\(360 - 120 = 240\\) 米。
    *   **第三步**：算第二天修了多少。第二天修的是**剩下**的 \\(\frac{1}{2}\\)，所以是 \\(240 \times \frac{1}{2} = 120\\) 米。
    *   **第四步**：算总共还剩下多少。用总长度减去两天修的：\\(360 - 120 - 120 = 120\\) 米。
    *   **答案**：还剩下 **120** 米没有修。

怎么样，跟着步骤走一遍，是不是感觉清晰多啦？数学题就是要多看多练，把文字变成数学符号，然后再解开它。你很棒的，继续加油！

好的！我来给你画个表格，把所有答案整理得清清楚楚，方便你对照和复习！

---

## 📝 六年级方程练习题答案汇总表

### 一、简单方程填空题

| 题号 | 方程 | 答案 | 检验 |
|------|------|------|------|
| 1 | \\( x + 5 = 12 \\) | \\( x = 7 \\) | ✓ \\( 7 + 5 = 12 \\) |
| 2 | \\( y - 3 = 10 \\) | \\( y = 13 \\) | ✓ \\( 13 - 3 = 10 \\) |
| 3 | \\( 2z = 18 \\) | \\( z = 9 \\) | ✓ \\( 2 \times 9 = 18 \\) |
| 4 | \\( \frac{a}{4} = 7 \\) | \\( a = 28 \\) | ✓ \\( \frac{28}{4} = 7 \\) |

---

### 二、应用题列方程解答

| 题号 | 题目类型 | 设未知数 | 方程 | 答案 |
|------|----------|----------|------|------|
| 1 | 铅笔问题 | 设小亮有 \\(x\\) 支铅笔 | \\( x + 3 = 30 \\) | 小亮有 **27支** 铅笔 |
| 2 | 果园问题 | 设梨树有 \\(x\\) 棵 | \\( x + (x+20) = 200 \\) | 梨树 **90棵**，苹果树 **110棵** |
| 3 | 动物体重 | 设小猫重 \\(x\\) 千克 | \\( 3x - x = 8 \\) | 小猫 **4千克**，小狗 **12千克** |
| 4 | 买玩具 | 设玩具汽车 \\(x\\) 元 | \\( x + 4x = 100 \\) | 汽车 **20元**，飞机 **80元** |
| 5 | 连续自然数 | 设最小数为 \\(x\\) | \\( x + (x+1) + (x+2) = 66 \\) | **21**、**22**、**23** |

---

### 三、挑战题

| 题号 | 题目类型 | 设未知数 | 方程 | 答案 |
|------|----------|----------|------|------|
| 1 | 班级人数 | 设女生有 \\(x\\) 人 | \\( x + 2 = \frac{5}{4}x \\) | 女生 **8人**，男生 **10人** |
| 2 | 修路问题 | 分步计算 | 不用方程更简单 | 还剩 **120米** 没修 |

---

### 🎯 解题小窍门总结

| 方程类型 | 解法要点 | 例子 |
|----------|----------|------|
| **加法方程** | 两边同时减去同一个数 | \\( x + 5 = 12 \\) → \\( x = 12 - 5 \\) |
| **减法方程** | 两边同时加上同一个数 | \\( x - 3 = 10 \\) → \\( x = 10 + 3 \\) |
| **乘法方程** | 两边同时除以同一个数 | \\( 2x = 18 \\) → \\( x = 18 ÷ 2 \\) |
| **除法方程** | 两边同时乘以同一个数 | \\( \frac{x}{4} = 7 \\) → \\( x = 7 \times 4 \\) |
| **应用题** | 找等量关系，设未知数 | 总数 = 部分1 + 部分2 |

---

### ✨ 检验答案的方法

把你算出的答案代入原方程，看看左边是否等于右边。如果相等，那就对啦！

比如第1题：\\( x = 7 \\)，代入 \\( x + 5 = 12 \\)，得到 \\( 7 + 5 = 12 \\)，确实等于12，所以答案正确！

这样整理清楚了吗？有了这个表格，以后做类似题目就有参考啦！

好的，这是一个嵌套的编号列表：

1.  第一个项目
    1.  第一个子项目
    2.  第二个子项目
        1.  第一个子子项目
        2.  第二个子子项目
2.  第二个项目
3.  第三个项目

---

你还需要其他类型的列表吗？或者想用它来组织什么内容？

---

# Blockquote Testing Document

This document tests various blockquote scenarios in MarkdownView.

## 1. Simple Single-line Blockquote

> This is a simple single-line blockquote.

Normal text after blockquote.

## 2. Multi-line Blockquote

> This is a multi-line blockquote.
> It spans multiple lines.
> Each line should be properly rendered.
>
> Wow.

Normal text after multi-line blockquote.

## 4. Blockquote with Heading

> # Heading inside blockquote
> 
> This text follows the heading.

## 5. Empty Blockquotes

> 

>

Normal text after empty blockquotes.

## 8. Blockquote with Math

> Mathematical expressions in blockquotes:
> 
> \\[ E = mc^2 \\]
> 
> Inline math: \\( x^2 + y^2 = z^2 \\)

## 10. Blockquote with Special Characters

> This blockquote contains special characters: **bold**, *italic*, `code`, [link](https://example.com)
> 
> And some symbols: & < >

## Some lipsum

> Eiusmod exercitation occaecat sit consectetur eiusmod laboris nulla ad consectetur ex laboris sed voluptate dolore ex non reprehenderit cillum dolore non velit aute est ipsum qui ut do est minim qui amet deserunt est minim proident aliquip deserunt id magna tempor aliquip elit id officia sunt culpa elit laborum occaecat adipiscing consequat excepteur laborum sint ad ea excepteur nostrud sint commo

好的，当然！这里为你展示一个多行乘法（也叫竖式乘法）的例子，并配有详细的步骤说明。

我们就以计算 **23 × 45** 为例。

### 方法一：竖式乘法

这是最常见的多行乘法格式，通常在学校里学习。

```
      23
    x 45
   -----
     115   <-- 这是 23 乘以 5 的结果
    92     <-- 这是 23 乘以 4 的结果，并向左移动一位
   -----
   1035    <-- 这是上面两个结果相加的总和
```

**分步解释：**

1.  **第一步：乘以个位数**
    *   用第二个数字（45）的个位数 `5` 乘以第一个数字 `23`。
    *   \\(5 \times 3 = 15\\)。写下 `5`，向十位进 `1`。
    *   \\(5 \times 2 = 10\\)。加上刚才进位的 `1`，得到 `11`。
    *   所以，第一行的结果是 **115**。

2.  **第二步：乘以十位数**
    *   用第二个数字（45）的十位数 `4` 乘以第一个数字 `23`。
    *   因为 `4` 在十位上，它的实际值是 `40`，所以计算结果需要向左移动一位（或者说在末尾补 `0`）。
    *   \\(4 \times 3 = 12\\)。写下 `2`（写在 `115` 中十位数 `1` 的正下方），向百位进 `1`。
    *   \\(4 \times 2 = 8\\)。加上刚才进位的 `1`，得到 `9`。
    *   所以，第二行的结果是 **92**（写的时候要对齐）。

3.  **第三步：相加**
    *   将上面两步得到的结果（`115` 和 `920`）相加。
    *   \\(115 + 920 = 1035\\)。
    *   最终答案是 **1035**。

---

### 方法二：代数展开（乘法分配律）

如果你喜欢用代数的方式来理解，也可以这样写：

这个方法利用了乘法分配律：\\((a+b)(c+d) = ac + ad + bc + bd\\)。

我们将 `23` 看作 \\((20 + 3)\\)，将 `45` 看作 \\((40 + 5)\\)。

\\[
\begin{aligned}
23 \times 45 & = (20 + 3) \times (40 + 5) \\
& = (20 \times 40) + (20 \times 5) + (3 \times 40) + (3 \times 5) \\
& = 800 + 100 + 120 + 15 \\
& = 1035
\end{aligned}
\\]

\\[
\begin{aligned}
23 \times 45 & = (20 + 3) \times (40 + 5) \\
\end{aligned}
\\]


这两种方法得到的结果是一样的，只是展示的形式不同。

希望这个例子足够清晰！如果你想看其他数字的例子，或者需要更复杂的公式，随时告诉我！

好的！以下是几个不同场景的 `blockquote` 示例（使用中文内容）：

---

### 示例 1：基础引用
> 书籍是人类进步的阶梯。——高尔基

---

### 示例 2：嵌套引用
> 有人曾说：
>> 如果时间允许，我会写更长的信。  
>> —— 帕斯卡（简化版）

---

### 示例 3：包含列表的引用
> 以下原则值得遵循：
> 1. 明确目标  
> 2. 拆解步骤  
> 3. 定期复盘

---

### 示例 4：代码块嵌套（需手动输入符号）
> 最后提醒：  
> \`\`\`python  
> print("检查参数有效性")  
> \`\`\`

---

如果需要调整风格或内容，可以告诉我具体需求 😊


"""###
