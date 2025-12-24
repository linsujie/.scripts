import json
import os
import re
from typing import Dict, List, Optional, Any
import requests
from datetime import datetime
from PaperAnalysis.PaperParser import PaperParser

class PaperAnalysisAgent:
    """论文分析Agent"""
    
    def __init__(self, paper_parser, api_key: str, base_url: str = "https://api.deepseek.com"):
        """
        初始化Agent
        
        Args:
            paper_parser: PaperParser对象
            api_key: DeepSeek API密钥
            base_url: API基础URL
        """
        self.paper = paper_parser
        self.api_key = api_key
        self.base_url = base_url
        self.results = {
            "introduction_summary": None,
            "chapter_mindmaps": {},
            "final_mindmap": None,
            "processed_chapters": []
        }

        os.path.isdir("paper_data") or os.mkdir("paper_data")
        self.state_file = "paper_data/paper_analysis_state.json"
        
        # 加载之前的状态（如果存在）
        self._load_state()
    
    def _load_state(self):
        """加载保存的状态"""
        if os.path.exists(self.state_file):
            try:
                with open(self.state_file, 'r', encoding='utf-8') as f:
                    saved_state = json.load(f)
                    # 只恢复已处理的结果，不覆盖paper对象
                    self.results.update(saved_state)
                print(f"✓ 已加载保存的状态，恢复{len(self.results['processed_chapters'])}个已处理章节")
            except Exception as e:
                print(f"⚠ 加载状态文件失败: {e}")
    
    def _save_state(self):
        """保存当前状态"""
        try:
            with open(self.state_file, 'w', encoding='utf-8') as f:
                json.dump(self.results, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"⚠ 保存状态文件失败: {e}")
    
    def _call_deepseek_api(self, system_prompt: str, user_content: str, model: str = "deepseek-reasoner") -> str:
        """
        调用DeepSeek API
        
        Args:
            system_prompt: 系统提示
            user_content: 用户内容
            model: 模型名称
            
        Returns:
            API返回的文本内容
        """
        url = f"{self.base_url}/v1/chat/completions"
        
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_content}
            ],
            "temperature": 1.3,
            "max_tokens": 4000
        }
        
        try:
            print("🔄 正在调用DeepSeek API...")
            response = requests.post(url, headers=headers, json=payload, timeout=60)
            response.raise_for_status()
            
            result = response.json()
            return result["choices"][0]["message"]["content"]
            
        except requests.exceptions.RequestException as e:
            print(f"❌ API调用失败: {e}")
            if hasattr(e, 'response') and e.response:
                print(f"响应内容: {e.response.text}")
            return ""
        except Exception as e:
            print(f"❌ 处理API响应时出错: {e}")
            return ""
    
    def step1_check_introduction(self) -> bool:
        """
        步骤1: 检查第一章是否为Introduction
        
        Returns:
            是否通过检查
        """
        print("=" * 60)
        print("步骤1: 检查论文结构")
        print("=" * 60)
        
        if len(self.paper.sections) == 0:
            print("❌ 论文没有章节")
            return False
        
        first_section_title = self.paper.sections[0].title.lower()
        
        # 检查是否包含"intro"或"introduction"
        if "intro" not in first_section_title:
            print(f"❌ 第一章标题不包含'Introduction'。当前标题: {self.paper.sections[0].title}")
            return False
        
        print(f"✓ 第一章检查通过: {self.paper.sections[0].title}")
        
        # 保存到状态
        self.results["introduction_checked"] = True
        self._save_state()
        
        return True
    
    def step2_summarize_introduction(self) -> bool:
        """
        步骤2: 概括Introduction内容
        
        Returns:
            是否成功
        """
        print("\n" + "=" * 60)
        print("步骤2: 概括Introduction内容")
        print("=" * 60)
        
        # 检查是否已处理
        if self.results["introduction_summary"]:
            print("✓ Introduction概括已存在，跳过处理")
            return True
        
        if len(self.paper.sections) == 0:
            print("❌ 论文没有章节")
            return False
        
        intro_section = self.paper.sections[0]
        
        # 构建系统提示
        system_prompt = """你是一位专业的科学论文分析专家。请仔细阅读论文的Introduction部分，并做出准确、全面的概括。

请按照以下结构进行概括：
1. 研究背景与重要性
2. 研究问题与挑战
3. 主要研究目标
4. 研究方法概述

请使用英文。请使用清晰、简洁的语言，确保概括完整且准确。"""

        # 用户内容
        user_content = f"""
论文标题: {self.paper.title}
Introduction标题: {intro_section.title}
Introduction内容:
{intro_section.content}
"""
    
        # 调用API
        summary = self._call_deepseek_api(system_prompt, user_content)
        
        if not summary:
            print("❌ 无法获取Introduction概括")
            return False
        
        # 保存结果
        self.results["introduction_summary"] = summary
        self._save_state()
        
        print(f"✓ Introduction概括完成，保存到状态")
        
        # 可选：将结果保存到单独文件
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        with open(f"paper_data/introduction_summary_{timestamp}.txt", "w", encoding="utf-8") as f:
            f.write(f"论文标题: {self.paper.title}\n")
            f.write(f"提取时间: {datetime.now()}\n")
            f.write(f"\n=== Introduction概括 ===\n\n")
            f.write(summary)
        
        return True
    
    def step3_generate_chapter_mindmaps(self, skip_chapters: List[str] = None) -> bool:
        """
        步骤3: 为各章节生成思维导图
        
        Args:
            skip_chapters: 要跳过的章节标题关键词列表
            
        Returns:
            是否成功
        """
        print("\n" + "=" * 60)
        print("步骤3: 为各章节生成思维导图")
        print("=" * 60)
        
        if skip_chapters is None:
            skip_chapters = ["conclusion", "acknowledgements", "acknowledgments", "reference", "appendix"]
        
        # 跳过第一章（Introduction）
        chapters_to_process = []
        for i, section in enumerate(self.paper.sections[1:], start=1):  # 从第二章开始
            section_title_lower = section.title.lower()
            
            # 检查是否应该跳过
            should_skip = False
            for keyword in skip_chapters:
                if keyword in section_title_lower:
                    should_skip = True
                    print(f"⏭️  跳过章节: {section.title} (包含关键词: {keyword})")
                    break
            
            if not should_skip:
                chapters_to_process.append((i, section))
        
        print(f"📚 需要处理 {len(chapters_to_process)} 个章节")
        
        success_count = 0
        for section_idx, section in chapters_to_process:
            section_key = f"section_{section_idx}_{section.title[:20]}"
            
            # 检查是否已处理
            if section_key in self.results["chapter_mindmaps"]:
                print(f"✓ 章节 '{section.title}' 已处理，跳过")
                success_count += 1
                continue
            
            print(f"\n📖 处理章节 {section_idx}: {section.title}")
            
            # 生成主章节的思维导图
            mindmap = self._generate_section_mindmap(section)
            
            if mindmap:
                self.results["chapter_mindmaps"][section_key] = {
                    "title": section.title,
                    "mindmap": mindmap,
                    "timestamp": datetime.now().isoformat()
                }
                success_count += 1
                
                # 保存到单独文件
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = f"paper_data/mindmap_{section_idx:02d}_{section.title[:30].replace(' ', '_')}_{timestamp}.mmd"
                with open(filename, "w", encoding="utf-8") as f:
                    f.write(f"%% 章节: {section.title}\n")
                    f.write(f"%% 生成时间: {datetime.now()}\n\n")
                    f.write(mindmap)
                
                print(f"  ✓ 主章节思维导图已保存到: {filename}")
            
            # 处理子章节
            if section.nsub > 0:
                print(f"  📋 处理 {section.nsub} 个子章节")
                for sub_idx, subsection in enumerate(section.subsections, start=1):
                    sub_key = f"{section_key}_subsection_{sub_idx}"
                    
                    # 检查是否已处理
                    if sub_key in self.results["chapter_mindmaps"]:
                        print(f"    ✓ 子章节 '{subsection.title}' 已处理，跳过")
                        continue
                    
                    print(f"    📝 处理子章节: {subsection.title}")
                    
                    # 生成子章节的思维导图
                    sub_mindmap = self._generate_section_mindmap(subsection, is_subsection=True)
                    
                    if sub_mindmap:
                        self.results["chapter_mindmaps"][sub_key] = {
                            "title": f"{section.title} - {subsection.title}",
                            "mindmap": sub_mindmap,
                            "timestamp": datetime.now().isoformat()
                        }
                        
                        # 保存到单独文件
                        sub_filename = f"paper_data/mindmap_{section_idx:02d}.{sub_idx}_{subsection.title[:20].replace(' ', '_')}_{timestamp}.mmd"
                        with open(sub_filename, "w", encoding="utf-8") as f:
                            f.write(f"%% 章节: {section.title} - {subsection.title}\n")
                            f.write(f"%% 生成时间: {datetime.now()}\n\n")
                            f.write(sub_mindmap)
                        
                        print(f"      ✓ 子章节思维导图已保存到: {sub_filename}")
            
            # 更新处理记录
            if section_key not in self.results["processed_chapters"]:
                self.results["processed_chapters"].append(section_key)
            
            # 保存状态
            self._save_state()
        
        print(f"\n🎉 章节处理完成: {success_count}/{len(chapters_to_process)} 个章节处理成功")
        return success_count > 0
    
    def _generate_section_mindmap(self, section, is_subsection: bool = False) -> str:
        """
        为单个章节生成思维导图
        
        Args:
            section: 章节对象
            is_subsection: 是否是子章节
            
        Returns:
            Mermaid格式的思维导图
        """
        section_type = "子章节" if is_subsection else "章节"
        
        system_prompt = f"""你是一位专业的科学论文分析专家。请为以下论文{section_type}内容创建Mermaid格式的思维导图。

思维导图要求：
1. 使用Mermaid的mindmap语法
    - 尽量不包含希腊字母、数学公式等复杂内容
    - 避免使用圆括号，方括号，花括号等特殊符号
2. 准确反映{section_type}的核心内容和结构
3. 层次清晰，重点突出
4. 使用适当的图标（可选）
5. 包含主要概念、方法
6. 思维导图应有合理的深度（3-4层）

请只输出Mermaid代码，不要添加解释或额外文本。请使用英文。"""

        user_content = f"""请为以下论文{section_type}创建Mermaid格式的思维导图：

{section_type}标题: {section.title}

{section_type}内容:
{section.content}

请生成思维导图的Mermaid代码："""
        
        mindmap = self._call_deepseek_api(system_prompt, user_content)
        
        # 清理输出，确保是有效的Mermaid代码
        if mindmap:
            # 提取可能的代码块
            code_match = re.search(r'```(?:mermaid)?\s*(.*?)\s*```', mindmap, re.DOTALL)
            if code_match:
                mindmap = code_match.group(1).strip()
            else:
                # 如果不是代码块格式，直接使用
                mindmap = mindmap.strip()
            
            # 确保以正确的语法开头
            if not mindmap.startswith("mindmap"):
                mindmap = f"mindmap\n  {section.title}\n{mindmap}"
        
        return mindmap
    
    def step4_generate_final_mindmap(self) -> bool:
        """
        步骤4: 生成综合工作思路图
        
        Returns:
            是否成功
        """
        print("\n" + "=" * 60)
        print("步骤4: 生成综合工作思路图")
        print("=" * 60)
        
        # 检查是否已处理
        if self.results["final_mindmap"]:
            print("✓ 综合工作思路图已存在，跳过处理")
            return True
        
        # 检查是否有足够的数据
        if not self.results["introduction_summary"]:
            print("❌ 请先完成步骤2（Introduction概括）")
            return False
        
        if len(self.results["chapter_mindmaps"]) == 0:
            print("❌ 请先完成步骤3（章节思维导图生成）")
            return False
        
        print("📊 汇总所有分析结果...")
        
        # 构建汇总内容
        summary_content = f"""论文标题: {self.paper.title}

=== Introduction概括 ===
{self.results['introduction_summary']}

=== 各章节思维导图摘要 ===
"""
        
        # 添加章节思维导图
        for key, data in self.results["chapter_mindmaps"].items():
            # 只取前200个字符作为摘要
            mindmap_preview = data["mindmap"][:200] + "..." if len(data["mindmap"]) > 200 else data["mindmap"]
            summary_content += f"\n章节: {data['title']}\n"
            summary_content += f"思维导图预览:\n{mindmap_preview}\n"
            summary_content += "-" * 40 + "\n"
        
        # 构建系统提示
        system_prompt = """你是一位专业的科学论文分析专家。请基于以下论文的Introduction概括和各章节思维导图，创建一张综合的工作思路图。

要求：
1. 使用Mermaid的mindmap语法
    - 尽量不包含希腊字母、数学公式等复杂内容
    - 避免使用圆括号，方括号，花括号等特殊符号
2. 整合论文的整体工作思路和逻辑流程
3. 包含以下要素：
   - 研究背景和问题
   - 研究方法和技术路线
   - 主要工作内容（基于各章节思维导图）
   - 实验设计和数据分析
   - 主要结果和结论
   - 创新点和贡献
4. 思维导图应展现论文工作的整体框架和内在逻辑
5. 层次清晰，重点突出
6. 可以使用图标增强可视化效果

请只输出Mermaid代码，不要添加解释或额外文本。请使用英文"""
        
        # 调用API
        final_mindmap = self._call_deepseek_api(system_prompt, summary_content)
        
        if not final_mindmap:
            print("❌ 无法生成综合工作思路图")
            return False
        
        # 清理输出
        code_match = re.search(r'```(?:mermaid)?\s*(.*?)\s*```', final_mindmap, re.DOTALL)
        if code_match:
            final_mindmap = code_match.group(1).strip()
        
        # 保存结果
        self.results["final_mindmap"] = final_mindmap
        self._save_state()
        
        # 保存到文件
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"paper_data/final_mindmap_{timestamp}.mmd"
        with open(filename, "w", encoding="utf-8") as f:
            f.write(f"%% 论文: {self.paper.title}\n")
            f.write(f"%% 综合工作思路图\n")
            f.write(f"%% 生成时间: {datetime.now()}\n\n")
            f.write(final_mindmap)
        
        print(f"✓ 综合工作思路图已保存到: {filename}")
        
        # 也保存为HTML以便查看
        self._save_mindmap_as_html(final_mindmap, f"paper_data/final_mindmap_{timestamp}.html")
        
        return True
    
    def _save_mindmap_as_html(self, mindmap_code: str, filename: str):
        """将思维导图保存为HTML文件"""
        html_template = f"""<!DOCTYPE html>
<html>
<head>
    <title>论文工作思路图</title>
    <script src="https://cdn.jsdelivr.net/npm/mermaid@10.6.1/dist/mermaid.min.js"></script>
    <script>mermaid.initialize({{startOnLoad: true}});</script>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; }}
        .mermaid {{ width: 100%; height: 800px; }}
        .info {{ margin-bottom: 20px; color: #666; }}
    </style>
</head>
<body>
    <div class="info">
        <h1>论文: {self.paper.title}</h1>
        <p>生成时间: {datetime.now()}</p>
    </div>
    <div class="mermaid">
{mindmap_code}
    </div>
</body>
</html>"""
        
        with open(filename, "w", encoding="utf-8") as f:
            f.write(html_template)
        print(f"📄 HTML预览文件已保存到: {filename}")
    
    def run_all_steps(self) -> bool:
        """
        运行所有步骤
        
        Returns:
            是否全部成功
        """
        print("🚀 开始运行论文分析Agent")
        print("=" * 60)
        
        steps = [
            ("步骤1: 检查论文结构", self.step1_check_introduction),
            ("步骤2: 概括Introduction", self.step2_summarize_introduction),
            ("步骤3: 生成章节思维导图", lambda: self.step3_generate_chapter_mindmaps()),
            ("步骤4: 生成综合工作思路图", self.step4_generate_final_mindmap)
        ]
        
        all_success = True
        for step_name, step_func in steps:
            print(f"\n▶️  开始{step_name}...")
            success = step_func()
            if not success:
                print(f"❌ {step_name}失败")
                all_success = False
                break
            print(f"✅ {step_name}完成")
        
        if all_success:
            print("\n🎉 所有步骤完成！")
            print("=" * 60)
            print("生成的文件:")
            print("1. introduction_summary_*.txt - Introduction概括")
            print("2. mindmap_*.mmd - 各章节思维导图")
            print("3. final_mindmap_*.mmd - 综合工作思路图")
            print("4. final_mindmap_*.html - 思维导图HTML预览")
            print("5. paper_analysis_state.json - 分析状态（用于断点续跑）")
        else:
            print("\n⚠️ 处理中断，已保存当前状态")
            print("下次运行将从断点处继续")
        
        return all_success
    
    def get_summary(self) -> Dict[str, Any]:
        """获取分析结果摘要"""
        return {
            "paper_title": self.paper.title,
            "introduction_summary_length": len(self.results["introduction_summary"]) if self.results["introduction_summary"] else 0,
            "chapters_processed": len(self.results["chapter_mindmaps"]),
            "has_final_mindmap": self.results["final_mindmap"] is not None,
            "processed_chapters_count": len(self.results["processed_chapters"])
        }


# 使用示例
if __name__ == "__main__":
    # 示例使用
    print("📚 论文分析Agent示例")
    print("-" * 60)
    
    # 注意：这里需要替换为实际的API密钥
    API_KEY = "sk-65df50e7a5b94ac99ce40b8ee88aed18"
    
    if API_KEY == "your-deepseek-api-key-here":
        print("⚠️  请先设置您的DeepSeek API密钥")
        print("修改代码中的 API_KEY 变量")
    else:
        # 创建PaperParser对象（这里需要您实际创建）
        paper = PaperParser("MarkDown/Ma et al. - 2023 - Interpretations of the cosmic ray secondary-to-pri/auto/Ma et al. - 2023 - Interpretations of the cosmic ray secondary-to-pri.md")
        
        # 示例：创建Agent（注释掉，因为需要实际的PaperParser对象）
        agent = PaperAnalysisAgent(paper, API_KEY)
        
        # 运行所有步骤
        success = agent.run_all_steps()
        
        # 或者单独运行某个步骤
        # agent.step1_check_introduction()
        # agent.step2_summarize_introduction()
        # agent.step3_generate_chapter_mindmaps()
        # agent.step4_generate_final_mindmap()
        
#        print("\n📋 使用说明:")
#        print("1. 将上面的API_KEY替换为您的DeepSeek API密钥")
#        print("2. 创建PaperParser对象，传入您的论文文件")
#        print("3. 创建PaperAnalysisAgent对象")
#        print("4. 调用run_all_steps()运行所有步骤，或单独调用各个步骤")
#        print("\n💾 断点续跑功能:")
#        print("- 每次API调用后自动保存状态")
#        print("- 中断后重新运行会从断点处继续")
#        print("- 状态文件: paper_analysis_state.json")
