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
  color: var(--el-text-color-primary);
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
  color: var(--el-text-color-primary);
}

.markdown-body :deep(h1) { font-size: 24px; }
.markdown-body :deep(h2) { font-size: 20px; }
.markdown-body :deep(h3) { font-size: 16px; }

.markdown-body :deep(p) {
  margin-bottom: 8px;
  color: var(--el-text-color-primary);
}

.markdown-body :deep(code) {
  background: var(--el-fill-color);
  padding: 2px 6px;
  border-radius: 4px;
  font-family: 'Consolas', 'Monaco', monospace;
  font-size: 13px;
  color: var(--el-text-color-primary);
}

.markdown-body :deep(.code-block-wrapper) {
  position: relative;
  margin: 12px 0;
}

.markdown-body :deep(.copy-btn) {
  position: absolute;
  top: 8px;
  right: 8px;
  background: var(--el-fill-color);
  color: var(--el-text-color-secondary);
  border: 1px solid var(--el-border-color);
  padding: 4px 12px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 12px;
  z-index: 10;
  transition: all 0.2s;
}

.markdown-body :deep(.copy-btn:hover) {
  background: var(--el-fill-color-light);
  color: var(--el-text-color-primary);
}

.markdown-body :deep(pre) {
  background: var(--el-fill-color-dark);
  color: var(--el-text-color-primary);
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
  border-left: 4px solid var(--el-color-primary);
  padding-left: 12px;
  margin: 12px 0;
  color: var(--el-text-color-secondary);
}

.markdown-body :deep(ul),
.markdown-body :deep(ol) {
  padding-left: 24px;
  margin: 8px 0;
  color: var(--el-text-color-primary);
}

.markdown-body :deep(li) {
  margin: 4px 0;
  color: var(--el-text-color-primary);
}

.markdown-body :deep(table) {
  border-collapse: collapse;
  width: 100%;
  margin: 12px 0;
}

.markdown-body :deep(th),
.markdown-body :deep(td) {
  border: 1px solid var(--el-border-color);
  padding: 8px 12px;
  text-align: left;
  color: var(--el-text-color-primary);
}

.markdown-body :deep(th) {
  background: var(--el-fill-color);
  font-weight: 600;
  color: var(--el-text-color-primary);
}

.markdown-body :deep(a) {
  color: var(--el-color-primary);
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
  border-top: 1px solid var(--el-border-color);
  margin: 16px 0;
}

/* 数学公式样式 */
.markdown-body :deep(.katex) {
  font-size: 1.1em;
  color: var(--el-text-color-primary);
}

.markdown-body :deep(.katex-html) {
  color: var(--el-text-color-primary);
}

.markdown-body :deep(.formula-block) {
  position: relative;
  margin: 16px 0;
  overflow-x: auto;
  text-align: center;
  background: var(--el-fill-color);
  padding: 16px;
  border-radius: 8px;
}

.markdown-body :deep(.formula-copy-btn) {
  position: absolute;
  top: 8px;
  right: 8px;
  background: var(--el-fill-color-light);
  border: none;
  padding: 4px 12px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 12px;
  color: var(--el-text-color-secondary);
  transition: all 0.2s;
}

.markdown-body :deep(.formula-copy-btn:hover) {
  background: var(--el-fill-color-dark);
  color: var(--el-text-color-primary);
}

/* 确保 KaTeX 内部元素颜色正确 */
.markdown-body :deep(.katex .mord),
.markdown-body :deep(.katex .mbin),
.markdown-body :deep(.katex .mrel),
.markdown-body :deep(.katex .mopen),
.markdown-body :deep(.katex .mclose),
.markdown-body :deep(.katex .mpunct),
.markdown-body :deep(.katex .mop) {
  color: var(--el-text-color-primary);
}
</style>
