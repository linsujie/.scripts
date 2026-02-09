#!/usr/bin/env python3
"""
tex2sound - LaTeX 文档转语音工具

将 LaTeX 文档转换为语音文件，支持中文数学公式转 Unicode。
使用讯飞语音合成服务。

用法: tex2sound <input.tex> <output_dir>

示例:
    tex2sound document.tex ./output
"""

import argparse
import asyncio
import base64
import hashlib
import hmac
import json
import os
import re
import subprocess
import sys
import time
import websocket
from datetime import datetime
from pathlib import Path
from typing import Optional
from urllib.parse import urlencode, urlparse


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
# 讯飞 TTS 配置
# ============================================================

XUNFEI_APP_ID = os.getenv('XUNFEI_APP_ID', 'your_app_id')
XUNFEI_API_SECRET = os.getenv('XUNFEI_API_SECRET', 'your_api_secret')
XUNFEI_API_KEY = os.getenv('XUNFEI_API_KEY', 'your_api_key')


# ============================================================
# 讯飞 TTS 模块
# ============================================================

def format_date_time(dt: datetime) -> str:
    """格式化时间为 RFC1123 格式"""
    return dt.strftime('%a, %d %b %Y %H:%M:%S GMT')


def create_auth_url(api_key: str, api_secret: str) -> str:
    """生成讯飞 TTS WebSocket 鉴权 URL"""
    # API 地址
    host_url = 'wss://tts-api.xfyun.cn/v2/tts'

    # 解析 URL
    ul = urlparse(host_url)

    # 生成时间戳
    date = format_date_time(datetime.now())

    # 生成签名字符串
    signature_origin = f"host: {ul.hostname}\ndate: {date}\nGET {ul.path} HTTP/1.1"

    # 使用 HMAC-SHA256 生成签名
    signature_sha = hmac.new(
        api_secret.encode('utf-8'),
        signature_origin.encode('utf-8'),
        digestmod=hashlib.sha256
    ).digest()

    # Base64 编码签名
    signature = base64.b64encode(signature_sha).decode(encoding='utf-8')

    # 生成 authorization 字符串
    authorization_origin = f'api_key="{api_key}", algorithm="hmac-sha256", headers="host date request-line", signature="{signature}"'
    authorization = base64.b64encode(authorization_origin.encode('utf-8')).decode(encoding='utf-8')

    # 生成完整 URL
    params = {
        'authorization': authorization,
        'date': date,
        'host': ul.hostname
    }
    url = f'{host_url}?{urlencode(params)}'

    return url


class XunfeiTTS:
    """讯飞 TTS 封装类"""

    def __init__(self, app_id: str, api_key: str, api_secret: str,
                 voice: str = "aisjiuxu", speed: int = 50,
                 volume: int = 50, pitch: int = 50):
        self.app_id = app_id
        self.api_key = api_key
        self.api_secret = api_secret
        self.voice = voice
        self.speed = speed
        self.volume = volume
        self.pitch = pitch
        self.audio_data = b''
        self.error = None

    def text_to_speech(self, text: str, output_file: str) -> bool:
        """将文本转换为语音文件"""
        self.audio_data = b''
        self.error = None

        # 删除旧文件
        if os.path.exists(output_file):
            os.remove(output_file)

        # 生成 URL
        try:
            url = create_auth_url(self.api_key, self.api_secret)
        except Exception as e:
            self.error = f"生成 URL 失败：{e}"
            return False

        # 创建 WebSocket 连接
        def on_open(ws):
            """连接建立的回调"""
            # 构建请求数据
            data = {
                "common": {
                    "app_id": self.app_id
                },
                "business": {
                    "aue": "lame",  # mp3 格式
                    "sfl": 1,  # 开启流式返回 mp3
                    "vcn": self.voice,
                    "speed": self.speed,
                    "volume": self.volume,
                    "pitch": self.pitch,
                    "tte": "utf8"
                },
                "data": {
                    "status": 2,  # 数据状态：2（表示数据发送完毕）
                    "text": base64.b64encode(text.encode('utf-8')).decode('utf-8')
                }
            }

            # 发送请求
            ws.send(json.dumps(data))

        def on_message(ws, message):
            """收到消息的回调"""
            try:
                data = json.loads(message)

                # 检查错误码
                if 'code' in data and data['code'] != 0:
                    self.error = data.get('message', 'Unknown error')
                    ws.close()
                    return

                # 检查是否有数据
                if 'data' not in data or data['data'] is None:
                    return

                # 收到音频数据
                audio_chunk = base64.b64decode(data['data']['audio'])
                self.audio_data += audio_chunk

                status = data['data']['status']
                if status == 2:
                    ws.close()

            except json.JSONDecodeError:
                pass
            except Exception as e:
                self.error = f"处理消息失败：{e}"
                ws.close()

        def on_error(ws, error):
            """错误的回调"""
            self.error = f"WebSocket 错误：{error}"
            ws.close()

        def on_close(ws, close_status_code, close_msg):
            """连接关闭的回调"""
            pass

        # 运行 WebSocket
        try:
            ws = websocket.WebSocketApp(
                url,
                on_open=on_open,
                on_message=on_message,
                on_error=on_error,
                on_close=on_close
            )
            ws.run_forever()
        except Exception as e:
            self.error = f"WebSocket 连接失败：{e}"
            return False

        # 检查是否成功
        if self.error:
            return False

        if not self.audio_data:
            self.error = "未收到音频数据"
            return False

        # 保存文件
        try:
            with open(output_file, 'wb') as f:
                f.write(self.audio_data)
            return True
        except Exception as e:
            self.error = f"保存文件失败：{e}"
            return False


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
# TTS 模块（使用讯飞）
# ============================================================

def text_to_speech(text: str, output_file: str, voice: str = "aisjiuxu",
                   speed: int = 50, volume: int = 50, pitch: int = 50) -> bool:
    """将文本转换为语音（使用讯飞 TTS）"""
    tts = XunfeiTTS(XUNFEI_APP_ID, XUNFEI_API_KEY, XUNFEI_API_SECRET,
                    voice=voice, speed=speed, volume=volume, pitch=pitch)
    return tts.text_to_speech(text, output_file)


def process_chapters_to_audio(chapters: list[str], output_dir: str,
                               voice: str = "aisjiuxu", speed: int = 50,
                               volume: int = 50, pitch: int = 50) -> list[str]:
    """将所有章节转换为音频文件"""
    audio_files = []

    for i, chapter_text in enumerate(chapters, 1):
        if not chapter_text.strip():
            continue

        output_file = os.path.join(output_dir, f'chapter_{i}.mp3')
        print(f"正在转换章节 {i}/{len(chapters)}...")

        success = text_to_speech(chapter_text, output_file, voice, speed, volume, pitch)
        if success:
            audio_files.append(output_file)
            print(f"  ✅ 章节转换成功")
        else:
            print(f"  ❌ 章节转换失败")

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


def check_xunfei_config() -> bool:
    """检查讯飞 TTS 配置"""
    if XUNFEI_APP_ID == 'your_app_id':
        return False
    return True


def main():
    parser = argparse.ArgumentParser(
        description='将 LaTeX 文档转换为语音文件（使用讯飞 TTS）',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
示例:
  %(prog)s document.tex ./output
  %(prog)s thesis.tex ./audio --voice aisjiuxu --speed 50
        '''
    )
    parser.add_argument('input_tex', help='输入的 LaTeX 文件')
    parser.add_argument('output_dir', help='输出目录')
    parser.add_argument('--voice', default='aisjiuxu',
                        help='TTS 语音（默认：aisjiuxu）')
    parser.add_argument('--speed', type=int, default=50,
                        help='语速 0-100（默认：50）')
    parser.add_argument('--volume', type=int, default=50,
                        help='音量 0-100（默认：50）')
    parser.add_argument('--pitch', type=int, default=50,
                        help='音调 0-100（默认：50）')
    parser.add_argument('--skip-tts', action='store_true',
                        help='跳过 TTS 转换，只生成文本文件')

    args = parser.parse_args()

    # 检查输入文件
    if not os.path.isfile(args.input_tex):
        print(f"错误：输入文件 '{args.input_tex}' 不存在")
        sys.exit(1)

    # 检查讯飞配置
    if not args.skip_tts and not check_xunfei_config():
        print("=" * 60)
        print("⚠️  讯飞 TTS 配置未设置")
        print("=" * 60)
        print()
        print("请设置以下环境变量：")
        print("  export XUNFEI_APP_ID='your_app_id'")
        print("  export XUNFEI_API_SECRET='your_api_secret'")
        print("  export XUNFEI_API_KEY='your_api_key'")
        print()
        print("或者直接在脚本中修改以下变量：")
        print("  XUNFEI_APP_ID")
        print("  XUNFEI_API_SECRET")
        print("  XUNFEI_API_KEY")
        print()
        print("获取方式：")
        print("1. 访问 https://console.xfyun.cn/")
        print("2. 注册/登录账号")
        print("3. 创建应用，选择语音合成（流式版）")
        print("4. 获取 APP ID、API Key 和 API Secret")
        print()
        print("如果只想生成文本文件，可以使用 --skip-tts 参数")
        sys.exit(1)

    # 创建输出目录
    os.makedirs(args.output_dir, exist_ok=True)

    # 获取 Lua 过滤器路径
    lua_filter_path = get_lua_filter_path()
    temp_lua_file = None

    try:
        print("=" * 60)
        print("tex2sound - LaTeX 文档转语音工具（讯飞 TTS）")
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
            print("Step 3: 转换为语音文件（讯飞 TTS）...")
            print(f"  语音：{args.voice}")
            print(f"  语速：{args.speed}")
            print(f"  音量：{args.volume}")
            print(f"  音调：{args.pitch}")
            print()
            audio_files = process_chapters_to_audio(
                chapters, args.output_dir,
                voice=args.voice,
                speed=args.speed,
                volume=args.volume,
                pitch=args.pitch
            )
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
    # 检查是否安装了必要库
    try:
        import websocket
    except ImportError:
        print("❌ 未安装 websocket-client")
        print("请运行：pip install websocket-client")
        sys.exit(1)

    main()
