import re
from dataclasses import dataclass
from typing import List, Optional

@dataclass
class Section:
    """章节类"""
    title: str
    content: str
    subsections: List['Section']  # 子章节列表
    
    def __init__(self, title: str, content: str = ""):
        self.title = title
        self.content = content
        self.subsections = []
    
    def __getitem__(self, index: int) -> 'Section':
        """支持通过索引访问子章节"""
        return self.subsections[index]
    
    @property
    def nsub(self) -> int:
        """返回子章节数量"""
        return len(self.subsections)
    
    def add_subsection(self, subsection: 'Section'):
        """添加子章节"""
        self.subsections.append(subsection)

class PaperParser:
    """Markdown论文解析器"""
    
    def __init__(self, filename: str):
        self.filename = filename
        self.title = ""
        self.abstract = ""
        self.sections: List[Section] = []
        
        # 解析论文
        self._parse_paper()
    
    def _parse_paper(self):
        """解析论文文件"""
        try:
            with open(self.filename, 'r', encoding='utf-8') as file:
                content = file.read()
            
            # 按行分割内容
            lines = [line.rstrip('\n') for line in content.split('\n')]
            
            # 找到第一个以'#'开头的行作为文章题目
            title_found = False
            abstract_start = None
            abstract_end = None
            
            for i, line in enumerate(lines):
                stripped = line.strip()
                
                # 找到标题（第一个以#开头的行）
                if not title_found and stripped.startswith('#'):
                    # 提取标题，去掉#号和空格
                    self.title = re.sub(r'^#+\s*', '', stripped)
                    title_found = True
                    abstract_start = i + 1
                    continue
                
                # 找到第一个章节标题（在标题之后）
                if title_found and not abstract_end and stripped.startswith('#'):
                    abstract_end = i
                    break
            
            abstract_lines = []
            # 提取摘要（标题之后，第一个章节之前的所有内容）
            if abstract_start is not None and abstract_end is not None:
                for i in range(abstract_start, abstract_end):
                    if lines[i].strip():  # 跳过空行
                        abstract_lines.append(lines[i])
                self._parse_markdown_sections(lines[abstract_end:])

            elif abstract_start is not None:
                # 如果没有找到章节标题，提取标题之后的所有内容作为摘要
                abstract_lines = []
                for i in range(abstract_start, len(lines)):
                    if lines[i].strip():  # 跳过空行
                        abstract_lines.append(lines[i])

            self.abstract = '\n'.join(abstract_lines)
            
        except FileNotFoundError:
            print(f"错误：文件 '{self.filename}' 不存在")
        except Exception as e:
            print(f"解析文件时出错：{e}")
    
    def _parse_markdown_sections(self, lines: List[str]):
        """解析Markdown格式的章节"""
        current_section = None
        current_subsection = None
        current_content = []
        
        for i, line in enumerate(lines):
            stripped = line.strip()
            
            # 跳过空行
            if not stripped:
                continue
            
            # 检查是否是章节标题（一级标题：#）
            if stripped.startswith('# ') and not stripped.startswith('##'):
                # 保存前一个章节
                if current_section:
                    current_section.content = '\n'.join(current_content)
                    self.sections.append(current_section)
                    current_content = []
                
                # 创建新章节
                section_title = re.sub(r'^#\s*([IVXLCDM]+|\d+).?\s*', '', stripped)
                current_section = Section(title=section_title)
                current_subsection = None
            
            # 检查是否是子章节标题（二级标题：##）
            elif stripped.startswith('## '):
                # 保存前一个子章节
                if current_subsection and current_section:
                    current_subsection.content = '\n'.join(current_content)
                    current_section.add_subsection(current_subsection)
                    current_content = []
                
                # 创建新子章节
                subsection_title = re.sub(r'^##\s*([A-Za-z]|\d+).?\s*', '', stripped)
                current_subsection = Section(title=subsection_title)
            
            # 如果是章节内容
            elif current_section:
                # 如果不是章节标题，则添加到当前内容
                current_content.append(line)
        
        # 保存最后一个章节
        if current_section:
            # 如果有最后一个子章节需要保存
            if current_subsection:
                current_subsection.content = '\n'.join(current_content)
                current_section.add_subsection(current_subsection)
                current_content = []
            else:
                current_section.content = '\n'.join(current_content)
            
            self.sections.append(current_section)
    
    def __getitem__(self, index: int) -> Section:
        """支持通过索引访问章节"""
        return self.sections[index]
    
    def __len__(self) -> int:
        """返回章节数量"""
        return len(self.sections)
    
    def print_structure(self):
        """打印论文结构"""
        print(f"标题: {self.title}")
        print(f"摘要: {self.abstract[:200]}..." if len(self.abstract) > 200 else f"摘要: {self.abstract}")
        print(f"章节数量: {len(self.sections)}")
        
        for i, section in enumerate(self.sections):
            print(f"\n章节 {i}: {section.title}")
            print(f"  内容长度: {len(section.content)} 字符")
            print(f"  子章节数量: {section.nsub}")
            
            for j, subsection in enumerate(section.subsections):
                print(f"  子章节 {j}: {subsection.title}")
                print(f"    内容长度: {len(subsection.content)} 字符")
    
    def get_section_by_title(self, title: str) -> Optional[Section]:
        """根据标题查找章节"""
        for section in self.sections:
            if section.title.lower() == title.lower():
                return section
        return None


# 使用示例
if __name__ == "__main__":
    # 将示例内容保存到文件
    print("=== 测试Markdown论文解析器 ===")
    paper = PaperParser("MarkDown/Ma et al. - 2023 - Interpretations of the cosmic ray secondary-to-pri/auto/Ma et al. - 2023 - Interpretations of the cosmic ray secondary-to-pri.md")
    
    print(f"论文标题: {paper.title}")
    print(f"\n摘要预览: {paper.abstract[:150]}...")
    
    if len(paper.sections) > 0:
        first_section = paper.sections[0]
        print(f"\n第一章标题: {first_section.title}")
        print(f"第一章内容预览: {first_section.content[:100]}...")
        print(f"第一章子章节数量: {first_section.nsub}")

        if first_section.nsub > 0:
            print(f"\n第一个子章节标题: {first_section[0].title}")
            print(f"第一个子章节内容: {first_section[0].content[:80]}...")
        
        for (i, section) in enumerate(paper.sections):
            print(f"\n第{i+1}章标题: {section.title}")
            print(f"第{i+1}章内容预览: {section.content[:100]}...")
            print(f"第{i+1}章子章节数量: {section.nsub}")

            for isub in range(section.nsub):
                print(f"\n   第{i+1}章第{isub+1}个子章节标题: {section[isub].title}")
                print(f"    第{i+1}章第{isub+1}个子章节内容预览: {section[isub].content[:80]}...")
    
    # 打印完整结构
    print("\n=== 论文完整结构 ===")
    paper.print_structure()
