# MoonBit Agent Skill

本代码仓库包含一个[Agent Skill](https://agentskills.io/home)，用于向AI编程代理传授MoonBit编程语言及其工具链的相关知识。

## 将该技能集成到你的代理中

不同的AI助手需要不同的配置方式。以下是主流编程助手的配置指南：

### Codex CLI

```shell
mkdir -p ~/.codex/skills/
git clone https://github.com/moonbitlang/moonbit-agent-guide ~/.codex/skills/moonbit
```

相关文档：https://developers.openai.com/codex/skills

### Claude Code

```shell
mkdir -p ~/.claude/skills/
git clone https://github.com/moonbitlang/moonbit-agent-guide ~/.claude/skills/moonbit
```

相关文档：https://code.claude.com/docs/en/skills

### GitHub Copilot for VS Code

```shell
# enable moonbit skill for current repository
mkdir -p ./.github/skills/
git clone https://github.com/moonbitlang/moonbit-agent-guide ./.github/skills/moonbit
```

注意：VS Code中对Agent Skills的支持目前处于预览阶段，且仅在[VS Code Insiders](https://code.visualstudio.com/insiders/)版本中可用。需启用`chat.useAgentSkills`设置项以使用Agent Skills。详细信息请参见《在VS Code中使用Agent Skills》：https://code.visualstudio.com/docs/copilot/customization/agent-skills

### Cursor & Cursor CLI

> Agent Skills仅在Cursor的夜间发布渠道中提供。

相关文档：https://cursor.com/cn/docs/context/skills

### Gemini CLI

Gemini CLI似乎将在下一个版本中支持agent skills：https://github.com/google-gemini/gemini-cli/issues/15327

### CodeBuddy

CodeBuddy 原生支持 Agent Skill，无需额外配置。只需确保 `moonbit-agent-guide` 目录位于你的工作区中，CodeBuddy 会自动识别并加载该技能。
