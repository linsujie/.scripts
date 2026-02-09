#!/usr/bin/env python3
"""
tex2sound - LaTeX 文档转语音工具

将 LaTeX 文档转换为语音文件，支持中文数学公式转 Unicode。

用法: tex2sound <input.tex> <output_dir>

示例:
    tex2sound document.tex ./output
"""

import argparse
import asyncio
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Optional

try:
    import edge_tts
except ImportError:
    edge_tts = None


# ============================================================
# Lua 过滤器内容（嵌入到 Python 中）
# ============================================================

MATH_TO_UNICODE_LUA = r'''local function math_to_unicode(text)
    -- 完整的希腊字母转换表
    local greek_letters = {
        -- 小写希腊字母
        ["\\alpha"] = "α",
        ["\\beta"] = "β",
        ["\\gamma"] = "γ",
        ["\\delta"] = "δ",
        ["\\epsilon"] = "ε",
        ["\\varepsilon"] = "ε",
        ["\\zeta"] = "ζ",
        ["\\eta"] = "η",
        ["\\theta"] = "θ",
        ["\\vartheta"] = "ϑ",
        ["\\iota"] = "ι",
        ["\\kappa"] = "κ",
        ["\\lambda"] = "λ",
        ["\\mu"] = "μ",
        ["\\nu"] = "ν",
        ["\\xi"] = "ξ",
        ["\\pi"] = "π",
        ["\\varpi"] = "ϖ",
        ["\\rho"] = "ρ",
        ["\\varrho"] = "ϱ",
        ["\\sigma"] = "σ",
        ["\\varsigma"] = "ς",
        ["\\tau"] = "τ",
        ["\\upsilon"] = "υ",
        ["\\phi"] = "φ",
        ["\\varphi"] = "φ",
        ["\\chi"] = "χ",
        ["\\psi"] = "ψ",
        ["\\omega"] = "ω",

        -- 大写希腊字母
        ["\\Alpha"] = "Α",
        ["\\Beta"] = "Β",
        ["\\Gamma"] = "Γ",
        ["\\Delta"] = "Δ",
        ["\\Epsilon"] = "Ε",
        ["\\Zeta"] = "Ζ",
        ["\\Eta"] = "Η",
        ["\\Theta"] = "Θ",
        ["\\Iota"] = "Ι",
        ["\\Kappa"] = "Κ",
        ["\\Lambda"] = "Λ",
        ["\\Mu"] = "Μ",
        ["\\Nu"] = "Ν",
        ["\\Xi"] = "Ξ",
        ["\\Pi"] = "Π",
        ["\\Rho"] = "Ρ",
        ["\\Sigma"] = "Σ",
        ["\\Tau"] = "Τ",
        ["\\Upsilon"] = "Υ",
        ["\\Phi"] = "Φ",
        ["\\Chi"] = "Χ",
        ["\\Psi"] = "Ψ",
        ["\\Omega"] = "Ω",
    }

    -- 数学符号和运算符
    local math_symbols = {
        -- 基本运算符
        ["\\pm"] = "±",
        ["\\mp"] = "∓",
        ["\\times"] = "×",
        ["\\div"] = "÷",
        ["\\cdot"] = "·",
        ["\\ast"] = "∗",
        ["\\star"] = "⋆",
        ["\\circ"] = "∘",
        ["\\bullet"] = "•",
        ["\\oplus"] = "⊕",
        ["\\ominus"] = "⊖",
        ["\\otimes"] = "⊗",
        ["\\oslash"] = "⊘",
        ["\\odot"] = "⊙",
        ["\\bigcirc"] = "◯",

        -- 关系符号
        ["\\leq"] = "≤",
        ["\\geq"] = "≥",
        ["\\neq"] = "≠",
        ["\\approx"] = "≈",
        ["\\equiv"] = "≡",
        ["\\propto"] = "∝",
        ["\\sim"] = "∼",
        ["\\simeq"] = "≃",
        ["\\cong"] = "≅",
        ["\\subset"] = "⊂",
        ["\\supset"] = "⊃",
        ["\\subseteq"] = "⊆",
        ["\\supseteq"] = "⊇",
        ["\\in"] = "∈",
        ["\\ni"] = "∋",
        ["\\notin"] = "∉",
        ["\\forall"] = "∀",
        ["\\exists"] = "∃",
        ["\\nexists"] = "∄",

        -- 微积分符号
        ["\\partial"] = "∂",
        ["\\nabla"] = "∇",
        ["\\infty"] = "∞",
        ["\\int"] = "∫",
        ["\\iint"] = "∬",
        ["\\iiint"] = "∭",
        ["\\oint"] = "∮",
        ["\\sum"] = "∑",
        ["\\prod"] = "∏",
        ["\\coprod"] = "∐",
        ["\\bigcap"] = "⋂",
        ["\\bigcup"] = "⋃",
        ["\\bigsqcup"] = "⨆",
        ["\\bigvee"] = "⋁",
        ["\\bigwedge"] = "⋀",

        -- 箭头符号
        ["\\rightarrow"] = "→",
        ["\\leftarrow"] = "←",
        ["\\Rightarrow"] = "⇒",
        ["\\Leftarrow"] = "⇐",
        ["\\leftrightarrow"] = "↔",
        ["\\Leftrightarrow"] = "⇔",
        ["\\mapsto"] = "↦",
        ["\\to"] = "→",
        ["\\gets"] = "←",

        -- 其他常用符号
        ["\\angle"] = "∠",
        ["\\triangle"] = "△",
        ["\\square"] = "□",
        ["\\diamond"] = "◇",
        ["\\parallel"] = "∥",
        ["\\perp"] = "⊥",
        ["\\ell"] = "ℓ",
        ["\\hbar"] = "ħ",
        ["\\emptyset"] = "∅",
        ["\\varnothing"] = "∅",
        ["\\mathbb{R}"] = "ℝ",
        ["\\mathbb{C}"] = "ℂ",
        ["\\mathbb{Q}"] = "ℚ",
        ["\\mathbb{Z}"] = "ℤ",
        ["\\mathbb{N}"] = "ℕ",
        ["\\aleph"] = "ℵ",
    }

    -- 下标和上标替换表
    local subscript_map = {
        ["0"] = "₀", ["1"] = "₁", ["2"] = "₂", ["3"] = "₃",
        ["4"] = "₄", ["5"] = "₅", ["6"] = "₆", ["7"] = "₇",
        ["8"] = "₈", ["9"] = "₉",
        ["a"] = "ₐ", ["b"] = "b", ["c"] = "c", ["d"] = "d",
        ["e"] = "ₑ", ["f"] = "f", ["g"] = "g", ["h"] = "ₕ",
        ["i"] = "ᵢ", ["j"] = "ⱼ", ["k"] = "ₖ", ["l"] = "ₗ",
        ["m"] = "ₘ", ["n"] = "ₙ", ["o"] = "ₒ", ["p"] = "ₚ",
        ["q"] = "q", ["r"] = "ᵣ", ["s"] = "ₛ", ["t"] = "ₜ",
        ["u"] = "ᵤ", ["v"] = "ᵥ", ["w"] = "w", ["x"] = "ₓ",
        ["y"] = "y", ["z"] = "z",
        ["+"] = "₊", ["-"] = "₋", ["="] = "₌", ["("] = "₍",
        [")"] = "₎",
    }

    local superscript_map = {
        ["0"] = "⁰", ["1"] = "¹", ["2"] = "²", ["3"] = "³",
        ["4"] = "⁴", ["5"] = "⁵", ["6"] = "⁶", ["7"] = "⁷",
        ["8"] = "⁸", ["9"] = "⁹",
        ["a"] = "ᵃ", ["b"] = "ᵇ", ["c"] = "ᶜ", ["d"] = "ᵈ",
        ["e"] = "ᵉ", ["f"] = "ᶠ", ["g"] = "ᵍ", ["h"] = "ʰ",
        ["i"] = "ᶦ", ["j"] = "ʲ", ["k"] = "ᵏ", ["l"] = "ˡ",
        ["m"] = "ᵐ", ["n"] = "ⁿ", ["o"] = "ᵒ", ["p"] = "ᵖ",
        ["q"] = "q", ["r"] = "ʳ", ["s"] = "ˢ", ["t"] = "ᵗ",
        ["u"] = "ᵘ", ["v"] = "ᵛ", ["w"] = "ʷ", ["x"] = "ˣ",
        ["y"] = "ʸ", ["z"] = "ᶻ",
        ["+"] = "⁺", ["-"] = "⁻", ["="] = "⁼", ["("] = "⁽",
        [")"] = "⁾",
    }

    -- 首先处理希腊字母和数学符号
    for latex, unicode in pairs(greek_letters) do
        text = text:gsub(latex, unicode)
    end

    for latex, unicode in pairs(math_symbols) do
        text = text:gsub(latex, unicode)
    end

    -- 处理下标
    text = text:gsub("_([%w%+%-%=%(%)])", function(match)
        return subscript_map[match] or "_" .. match
    end)

    -- 处理带花括号的下标
    text = text:gsub("_(%b{})", function(braced)
        local content = braced:sub(2, -2)
        if #content == 1 and subscript_map[content] then
            return subscript_map[content]
        else
            -- 多字符下标保持原样或可以进一步处理
            return "_{" .. content .. "}"
        end
    end)

    -- 处理上标
    text = text:gsub("%^([%w%+%-%=%(%)])", function(match)
        return superscript_map[match] or "^" .. match
    end)

    -- 处理带上标的花括号
    text = text:gsub("%^(%b{})", function(braced)
        local content = braced:sub(2, -2)
        if #content == 1 and superscript_map[content] then
            return superscript_map[content]
        else
            return "^{" .. content .. "}"
        end
    end)

    -- 移除多余的括号
    text = text:gsub("_{%[%^%{([^}]+)%}%]}", "_{%1}")  -- 清理嵌套括号

    return text
end

function Math(elem)
    -- 只转换行内数学和行间数学
    if elem.mathtype == "InlineMath" or elem.mathtype == "DisplayMath" then
        elem.text = math_to_unicode(elem.text)
    end
    return elem
end

function RawInline(elem)
    -- 处理原始的LaTeX数学环境
    if elem.format == "tex" then
        if elem.text:match("^%$.*%$$") or elem.text:match("^%$%$.+%$%$$") then
            local text = elem.text:gsub("^%$", ""):gsub("%$$", "")
            text = math_to_unicode(text)
            return pandoc.Math(elem.mathtype or "InlineMath", text)
        end
    end
    return elem
end

return {
    {Math = Math},
    {RawInline = RawInline}
}
'''


# ============================================================
# 预处理模块
# ============================================================

def preprocess_line(line: str, is_title: bool = False) -> str:
    """预处理单行文本，去除 Markdown 语法，保留纯文本"""
    if is_title:
        return re.sub(r'^#+\s+', '', line)

    # 将不间断空格（NBSP, \xc2\xa0）转换为普通空格
    line = line.replace('\xc2\xa0', ' ')

    # 处理 LaTeX 数学格式（在删除反斜杠之前处理）
    line = re.sub(r'\\mathrm\{([^}]+)\}', r'\1', line)
    line = re.sub(r'\\text\{([^}]+)\}', r'\1', line)
    line = re.sub(r'\\lambda', 'λ', line)
    line = re.sub(r'\\mu', 'μ', line)
    line = re.sub(r'\\tau', 'τ', line)
    line = re.sub(r'\\alpha', 'α', line)
    line = re.sub(r'\\theta', 'θ', line)
    line = re.sub(r'\\cdot', '·', line)
    line = re.sub(r'\^\{([^}]+)\}', r'\1', line)
    line = re.sub(r'_\{([^}]+)\}', r'\1', line)

    # 去除孤立的 {数字} 格式
    line = re.sub(r'\{\d+\}', '', line)

    # 去除转义的反斜杠（pandoc 转换产生的）
    line = re.sub(r'\\', '', line)

    # 压缩多个空格
    line = re.sub(r'[ \t]{2,}', ' ', line)

    # 去除粗体标记
    line = re.sub(r'\*\*([^*]+)\*\*', r'\1', line)
    line = re.sub(r'__([^_]+)__', r'\1', line)

    # 去除斜体标记
    line = re.sub(r'\*([^*]+)\*', r'\1', line)
    line = re.sub(r'_([^_]+)_', r'\1', line)

    # 去除删除线标记
    line = re.sub(r'\s*~~([^~]+)~~\s*', r'\1', line)

    # 去除链接语法
    line = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', line)

    # 去除行内代码
    line = re.sub(r'`([^`]+)`', r'\1', line)

    # 去除 HTML 标签
    line = re.sub(r'<[^>]+>', '', line)

    # 压缩空格
    line = re.sub(r'\s+', ' ', line)

    # 去除行首行尾空格
    line = line.strip()

    return line


def remove_images_and_math(content: str) -> str:
    """去除图片引用和数学符号"""
    # 删除整个 <figure>...</figure> 块
    content = re.sub(r'<figure[^>]*>.*?</figure>', '', content, flags=re.DOTALL)

    # 删除 Markdown 图片及其属性
    content = re.sub(r'!\[.*?\]\(.*?\)\{[^}]*\}', '', content)
    content = re.sub(r'!\[.*?\]\(.*?\)', '', content)

    # 删除图片和表格引用
    content = re.sub(r'\[\d+\.?\d*\]\(#.*?\)\{[^}]*\}', '', content)
    content = re.sub(r'\[表\d+\.?\d*\]\(#.*?\)\{[^}]*\}', '', content)

    # 删除表格块
    content = re.sub(r':::\s*\{[^}]*\}.*?:::', '', content, flags=re.DOTALL)

    # 去除所有 $ 符号
    content = content.replace('$', '')

    return content


def convert_latex_to_chapters(input_tex: str, lua_filter_path: Optional[str] = None) -> tuple[int, list[str]]:
    """
    将 LaTeX 转换为章节文件

    Returns:
        (章节数量, 章节文件路径列表)
    """
    # 构建 pandoc 命令
    cmd = ['pandoc', '-f', 'latex', '-t', 'markdown']
    if lua_filter_path:
        cmd.extend(['--lua-filter', lua_filter_path])
    cmd.append(input_tex)

    # 执行 pandoc
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        check=True
    )

    markdown_content = result.stdout

    # 去除图片和数学符号
    markdown_content = remove_images_and_math(markdown_content)

    # 按章节分割
    chapter_num = 0
    chapter_lines = []
    chapters = []

    lines = markdown_content.split('\n')
    in_code_block = False

    for line in lines:
        # 检测代码块
        if re.match(r'^\s*```', line):
            in_code_block = not in_code_block
            continue

        if in_code_block:
            continue

        # 跳过缩进的代码块
        if re.match(r'^\s{4,}', line):
            continue

        # 检测章节标题
        if re.match(r'^#+\s', line):
            # 保存上一个章节
            if chapter_lines:
                chapters.append('\n'.join(chapter_lines))

            # 开始新章节
            chapter_num += 1
            title_text = preprocess_line(line, is_title=True)
            chapter_lines = [f'【{title_text}】', '']
        else:
            if chapter_lines:
                if not line.strip():
                    chapter_lines.append('')
                else:
                    clean_line = preprocess_line(line, is_title=False)
                    if clean_line:
                        chapter_lines.append(clean_line)

    # 保存最后一个章节
    if chapter_lines:
        chapters.append('\n'.join(chapter_lines))

    return chapter_num, chapters


# ============================================================
# TTS 模块
# ============================================================

async def text_to_speech(text: str, output_file: str, voice: str = "zh-CN-YunyangNeural", rate: str = "-20%") -> bool:
    """将文本转换为语音"""
    if edge_tts is None:
        print("错误：未安装 edge-tts，请运行: pip install edge-tts")
        return False

    try:
        communicate = edge_tts.Communicate(text, voice, rate=rate)
        await communicate.save(output_file)
        return True
    except Exception as e:
        print(f"错误：TTS 转换失败: {e}")
        return False


async def process_chapters_to_audio(chapters: list[str], output_dir: str, voice: str = "zh-CN-YunyangNeural", rate: str = "-20%") -> list[str]:
    """将所有章节转换为音频文件"""
    audio_files = []

    for i, chapter_text in enumerate(chapters, 1):
        if not chapter_text.strip():
            continue

        output_file = os.path.join(output_dir, f'chapter_{i}.mp3')
        print(f"正在转换章节 {i}/{len(chapters)}...")

        success = await text_to_speech(chapter_text, output_file, voice, rate)
        if success:
            audio_files.append(output_file)
        else:
            print(f"警告：章节 {i} 转换失败")

    return audio_files


# ============================================================
# 主程序
# ============================================================

def get_lua_filter_path() -> Optional[str]:
    """获取 Lua 过滤器文件路径"""
    # 首先尝试从脚本所在目录查找
    script_dir = os.path.dirname(os.path.abspath(__file__))
    lua_path = os.path.join(script_dir, 'math-to-unicode.lua')
    if os.path.exists(lua_path):
        return lua_path

    # 如果不存在，创建临时文件
    import tempfile
    temp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.lua', delete=False, encoding='utf-8')
    temp_file.write(MATH_TO_UNICODE_LUA)
    temp_file.close()
    return temp_file.name


def main():
    parser = argparse.ArgumentParser(
        description='将 LaTeX 文档转换为语音文件',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
示例:
  %(prog)s document.tex ./output
  %(prog)s thesis.tex ./audio --voice zh-CN-XiaoxiaoNeural
        '''
    )
    parser.add_argument('input_tex', help='输入的 LaTeX 文件')
    parser.add_argument('output_dir', help='输出目录')
    parser.add_argument('--voice', default='zh-CN-YunyangNeural',
                        help='TTS 语音（默认：zh-CN-YunyangNeural）')
    parser.add_argument('--rate', default='-20%',
                        help='语音速度（默认：-20%）')
    parser.add_argument('--skip-tts', action='store_true',
                        help='跳过 TTS 转换，只生成文本文件')

    args = parser.parse_args()

    # 检查输入文件
    if not os.path.isfile(args.input_tex):
        print(f"错误：输入文件 '{args.input_tex}' 不存在")
        sys.exit(1)

    # 创建输出目录
    os.makedirs(args.output_dir, exist_ok=True)

    # 获取 Lua 过滤器路径
    lua_filter_path = get_lua_filter_path()
    temp_lua_file = None

    try:
        print("=" * 60)
        print("tex2sound - LaTeX 文档转语音工具")
        print("=" * 60)
        print()

        # Step 1: 转换 LaTeX 到章节文本
        print("Step 1: 转换 LaTeX 到章节文本...")
        chapter_num, chapters = convert_latex_to_chapters(args.input_tex, lua_filter_path)
        print(f"✅ 成功生成 {chapter_num} 个章节")
        print()

        # Step 2: 保存章节文本文件
        print("Step 2: 保存章节文本文件...")
        text_files = []
        for i, chapter_text in enumerate(chapters, 1):
            text_file = os.path.join(args.output_dir, f'chapter_{i}.txt')
            with open(text_file, 'w', encoding='utf-8') as f:
                f.write(chapter_text)
            text_files.append(text_file)
        print(f"✅ 已保存 {len(text_files)} 个文本文件")
        print()

        # Step 3: TTS 转换
        if not args.skip_tts:
            print("Step 3: 转换为语音文件...")
            audio_files = asyncio.run(process_chapters_to_audio(chapters, args.output_dir, args.voice, args.rate))
            print(f"✅ 已生成 {len(audio_files)} 个语音文件")
            print()

            # 输出摘要
            print("=" * 60)
            print("转换完成！")
            print("=" * 60)
            print(f"输出目录: {args.output_dir}")
            print()
            print("生成的文件:")
            for text_file, audio_file in zip(text_files, audio_files):
                print(f"  {os.path.basename(text_file)} + {os.path.basename(audio_file)}")
        else:
            print("=" * 60)
            print("文本文件生成完成！（跳过 TTS 转换）")
            print("=" * 60)
            print(f"输出目录: {args.output_dir}")
            print()
            print("生成的文件:")
            for text_file in text_files:
                print(f"  {os.path.basename(text_file)}")

    finally:
        # 清理临时文件
        if temp_lua_file and os.path.exists(temp_lua_file):
            os.unlink(temp_lua_file)


if __name__ == '__main__':
    main()
