<template>
  <div class="markdown-body" v-html="renderedContent" @click="handleClick"></div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { marked } from 'marked'
import katex from 'katex'
import { ElMessage } from 'element-plus'

const props = defineProps<{
  content: string
}>()

async function copyToClipboard(text: string) {
  try {
    await navigator.clipboard.writeText(text)
    ElMessage.success('已复制')
  } catch {
    ElMessage.error('复制失败')
  }
}

function handleClick(e: Event) {
  const target = e.target as HTMLElement
  if (target.classList.contains('copy-btn')) {
    const codeBlock = target.closest('.code-block-wrapper')
    const code = codeBlock?.querySelector('code')?.textContent || ''
    copyToClipboard(code)
  }
  if (target.classList.contains('formula-copy-btn')) {
    const formula = target.getAttribute('data-formula') || ''
    copyToClipboard(formula)
  }
}

function renderFormula(formula: string, displayMode: boolean): string {
  try {
    return katex.renderToString(formula.trim(), { throwOnError: false, displayMode })
  } catch (e) {
    console.warn('KaTeX render error:', e)
    return displayMode ? `<pre>$$${formula}$$</pre>` : `<code>$${formula}$</code>`
  }
}

const renderedContent = computed(() => {
  if (!props.content) return ''
  try {
    let content = props.content

    // 存储公式占位符
    const formulas: { placeholder: string; html: string }[] = []
    let index = 0

    // 1. 先处理块级公式
    // 处理 \[...\] 格式
    content = content.replace(/\\\[([\s\S]+?)\\\]/g, (match, formula) => {
      const placeholder = `%%BLOCK_FORMULA_${index}%%`
      const html = `<div class="formula-block">${renderFormula(formula, true)}<button class="formula-copy-btn" data-formula="${formula.trim().replace(/"/g, '&quot;')}">复制</button></div>`
      formulas.push({ placeholder, html })
      index++
      return placeholder
    })

    // 处理 $$...$$ 格式
    content = content.replace(/\$\$([\s\S]+?)\$\$/g, (match, formula) => {
      const placeholder = `%%BLOCK_FORMULA_${index}%%`
      const html = `<div class="formula-block">${renderFormula(formula, true)}<button class="formula-copy-btn" data-formula="${formula.trim().replace(/"/g, '&quot;')}">复制</button></div>`
      formulas.push({ placeholder, html })
      index++
      return placeholder
    })

    // 2. 处理行内公式
    // 处理 \(...\) 格式
    content = content.replace(/\\\((.+?)\\\)/g, (match, formula) => {
      if (formula.includes('<') || formula.includes('>')) return match
      const placeholder = `%%INLINE_FORMULA_${index}%%`
      const html = renderFormula(formula, false)
      formulas.push({ placeholder, html })
      index++
      return placeholder
    })

    // 处理 $...$ 格式（排除已经处理过的）
    content = content.replace(/(?<!\$)\$(?!\$)([^$\n]+?)\$(?!\$)/g, (match, formula) => {
      if (formula.includes('<') || formula.includes('>')) return match
      if (formula.includes('%%')) return match
      const placeholder = `%%INLINE_FORMULA_${index}%%`
      const html = renderFormula(formula, false)
      formulas.push({ placeholder, html })
      index++
      return placeholder
    })

    // 3. 渲染 Markdown
    let result = marked.parse(content, { async: false }) as string

    // 4. 恢复公式
    for (const { placeholder, html } of formulas) {
      result = result.replace(placeholder, html)
    }

    // 5. 给代码块添加复制按钮
    result = result.replace(/<pre><code(.*?)>([\s\S]*?)<\/code><\/pre>/g, (match, attrs, code) => {
      return `<div class="code-block-wrapper"><button class="copy-btn">复制</button><pre><code${attrs}>${code}</code></pre></div>`
    })

    return result
  } catch (e) {
    console.error('Markdown render error:', e)
    return props.content
  }
})
</script>

<style scoped>
.markdown-body {
  font-size: 14px;
  line-height: 1.8;
  word-break: break-word;
}

.markdown-body :deep(h1),
.markdown-body :deep(h2),
.markdown-body :deep(h3),
.markdown-body :deep(h4),
.markdown-body :deep(h5),
.markdown-body :deep(h6) {
  margin-top: 16px;
  margin-bottom: 8px;
  font-weight: 600;
  line-height: 1.4;
}

.markdown-body :deep(h1) { font-size: 24px; }
.markdown-body :deep(h2) { font-size: 20px; }
.markdown-body :deep(h3) { font-size: 16px; }

.markdown-body :deep(p) {
  margin-bottom: 8px;
}

.markdown-body :deep(code) {
  background: #f0f0f0;
  padding: 2px 6px;
  border-radius: 4px;
  font-family: 'Consolas', 'Monaco', monospace;
  font-size: 13px;
}

.markdown-body :deep(.code-block-wrapper) {
  position: relative;
  margin: 12px 0;
}

.markdown-body :deep(.copy-btn) {
  position: absolute;
  top: 8px;
  right: 8px;
  background: rgba(255, 255, 255, 0.1);
  color: #d4d4d4;
  border: 1px solid rgba(255, 255, 255, 0.2);
  padding: 4px 12px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 12px;
  z-index: 10;
  transition: all 0.2s;
}

.markdown-body :deep(.copy-btn:hover) {
  background: rgba(255, 255, 255, 0.2);
}

.markdown-body :deep(pre) {
  background: #1e1e1e;
  color: #d4d4d4;
  padding: 16px;
  border-radius: 8px;
  overflow-x: auto;
  margin: 0;
}

.markdown-body :deep(pre code) {
  background: transparent;
  padding: 0;
  color: inherit;
}

.markdown-body :deep(blockquote) {
  border-left: 4px solid #409eff;
  padding-left: 12px;
  margin: 12px 0;
  color: #606266;
}

.markdown-body :deep(ul),
.markdown-body :deep(ol) {
  padding-left: 24px;
  margin: 8px 0;
}

.markdown-body :deep(li) {
  margin: 4px 0;
}

.markdown-body :deep(table) {
  border-collapse: collapse;
  width: 100%;
  margin: 12px 0;
}

.markdown-body :deep(th),
.markdown-body :deep(td) {
  border: 1px solid #e0e0e0;
  padding: 8px 12px;
  text-align: left;
}

.markdown-body :deep(th) {
  background: #f5f5f5;
  font-weight: 600;
}

.markdown-body :deep(a) {
  color: #409eff;
  text-decoration: none;
}

.markdown-body :deep(a:hover) {
  text-decoration: underline;
}

.markdown-body :deep(img) {
  max-width: 100%;
  border-radius: 8px;
}

.markdown-body :deep(hr) {
  border: none;
  border-top: 1px solid #e0e0e0;
  margin: 16px 0;
}

/* 数学公式样式 */
.markdown-body :deep(.katex) {
  font-size: 1.1em;
}

.markdown-body :deep(.formula-block) {
  position: relative;
  margin: 16px 0;
  overflow-x: auto;
  text-align: center;
  background: #f8f8f8;
  padding: 16px;
  border-radius: 8px;
}

.markdown-body :deep(.formula-copy-btn) {
  position: absolute;
  top: 8px;
  right: 8px;
  background: #e0e0e0;
  border: none;
  padding: 4px 12px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 12px;
  color: #606266;
  transition: all 0.2s;
}

.markdown-body :deep(.formula-copy-btn:hover) {
  background: #d0d0d0;
}
</style>
