# Agentic programming results

As mentioned in the [README](README.md), this project is a personal test bench for agentic programming. I'm not a "vibe coder", but I do think it is important to understand and explore the new tools AI has brought to us. For this reason, 99% of the code in this project is AI generated. In this file I'll explain how I'm approaching the implementation of the different tasks, and the results the agents have given me.

Another important note on these observations. I'm a back-end developer, I know my way around some CSS and HTML but it's not my sharpest skill. Take my considerations about how the agents handle front-end tasks with a grain of salt. 

## Tasks 1 to 7, HTML plans and free project exploration

- **Harness:** Codex (desktop app)
- **Models:** GPT 5.5 (medium and high reasoning mostly)
- **Methodology**
  - All conversations start with the generation of a [HTML plan](https://claude.com/blog/using-claude-code-the-unreasonable-effectiveness-of-html) based on one to two tasks defined in the [general plan](https://github.com/carloosaf/ascents/blob/main/.plans/ascents-social-plan.html).
  - We specify the plan must contain "all relevant questions and risks"
  - After a manual review of the plan, we address the questions and risks and ask for any other change we think necessary.
  - Once the plan looks correct, we simply tell the agent to start the implementation.
  - When the agent finishes, we manually review the code and ask for any fix or clarification.
- **Notes:**
  - Plan mode was never used, the plan itself is generated via the build mode.

### Observations

1. The results are surprisingly good, the plans ask relevant questions, and the functionality does not seem to have any bugs. These tasks are quite simple, mostly CRUD operations on the database, so this may vary with more complex work. 
2. Out of the found bugs or errors, they tend to be on the side of design. There were mainly two types of design errors:
  1. Simple errors like bad layout, weird padding and general lack of good UX. These were generally quite obvious and easy to fix. A simple explanation and a screenshot of the error are enough for the agent to fix them. Out of these mistakes, the worst was at the point of designing the component system, the agent did not create variables for the colours it used, hardcoding all of them as hex values all around the application. 
  2. Generally the model lacks awareness of the context of the application. For example, the routes page optionally shows an image of each route. Climbing is obviously a very vertical sport, these routes are meant to be tall, but the layout chosen by the model is a grid where images are laid out in a landscape manner. This is quite obvious for any human designing an application but seems to be out of the reasoning of the model, even in high settings. This kind of product-driven thinking is still needed by the user leading the agent. 
3. When doing task 3 "Design system and component gallery", the first design had the very common "AI feel" to it. After some back and forth and the use of a custom SKILL, I was able to steer the agent into creating a more "unique" design. 
4. Compared with my previous experience using other harnesses (mainly GitHub Copilot and OpenCode), Codex and GPT 5.5 take considerably longer to develop any task. I do not have any real data, but my impression is that they take between two to three times longer, even in lower reasoning levels. The results are satisfactory, and generally faster than what it would take me to do it completely by hand, so it is still worth it. For smaller fixes, I'd rather do a small and fast OpenCode thread than use Codex. 
5. HTML plans seem like a good idea; they are more expressive for both the human reviewing them and the agent itself. The first couple of plans required a bit of messing around, but once we had a couple of examples the next plans were pretty good. Questions and risks were generally relevant.
6. I've not seen any big errors in the business logic side of things, the Phoenix contexts were pretty spot on. I think this is due to the already mentioned simplicity of the application, but it might also be because they are "harder" errors to find. Front-end bugs are very visible, but this kind of business logic bug might escape my notice because I have not tested the application enough. I'll note on this once I deploy it and test it further.
7. This kind of AI-heavy workflow, combined with Codex remote work with its desktop and Android apps allows for some incredible use of free time. I found myself just running an agent in the background while running errands or doing chores. This is a great increase of productivity, I tend to struggle to find time and motivation for personal projects and this makes the "dopamine loop" of getting cool new things done way more frictionless. I'm aware this can tend to create poorer code, there is no way less focused work leads to better products, but in the case of a side project like this or creating fast MVPs I think it's okay. For professional work, I would not recommend this workflow without more focused review.
