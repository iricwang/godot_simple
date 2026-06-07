@tool
extends McpClient

## DeepSeek desktop application MCP configuration.
## Stores MCP servers under mcpServers in a per-user JSON config file.
## https://www.deepseek.com


func _init() -> void:
	id = "deepseek"
	display_name = "DeepSeek"
	config_type = "json"
	doc_url = "https://platform.deepseek.com"
	path_template = {
		"darwin": "~/Library/Application Support/DeepSeek/mcp.json",
		"windows": "$APPDATA/DeepSeek/mcp.json",
		"linux": "$XDG_CONFIG_HOME/deepseek/mcp.json",
	}
	server_key_path = PackedStringArray(["mcpServers"])
	## DeepSeek uses streamableHttp transport for MCP server connections.
	entry_extra_fields = {"type": "streamableHttp"}
	detect_paths = PackedStringArray(path_template.values())
