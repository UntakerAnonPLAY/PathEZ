"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[892],{1132:e=>{e.exports=JSON.parse('{"functions":[],"properties":[{"name":"Errored","desc":"A signal connection to handle errors from agents.\\n\\n```lua\\nlocal PathEZ = require(game:GetService(\\"ReplicatedStorage\\").Packages.PathEZ)\\n\\nfunction errorHandler(error: PathEZ.Error)\\n\\tif error.Agent.Name == \\"Oleg\\" and error.errorType == Enum.PathStatus.NoPath then\\n\\t\\tprint(\\"Oleg can\'t reach the target\\")\\n\\tend\\nend\\n\\nPathEZ.Errored:Connect(errorHandler)\\n```\\n\\n:::info\\n\\nThis signal connection will provide errors from ALL agents initialized in the same script.\\n\\nThis means you have to filter errors by agent to handle errors from a specific agent.\\nOr have a separate script for each agent, what is harmful for perfomance.\\n\\n:::\\n\\nMore info about [Signals](https://sleitnick.github.io/RbxUtil/api/Signal) API.","lua_type":"Signal","source":{"line":133,"path":"PathEZ/init.lua"}}],"types":[{"name":"Error","desc":"Errors are fired using [Sleitnick\'s Signal API](https://sleitnick.github.io/RbxUtil/api/Signal).","fields":[{"name":"Agent","lua_type":"Model","desc":"agent, who caused an error"},{"name":"errorType","lua_type":"string | Enum","desc":""},{"name":"errorMessage","lua_type":"string","desc":"description of an error"}],"source":{"line":79,"path":"PathEZ/init.lua"}}],"name":"Error","desc":"Class for Error handling","source":{"line":69,"path":"PathEZ/init.lua"}}')}}]);