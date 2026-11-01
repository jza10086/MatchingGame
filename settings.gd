## Business-owned setting defaults, constraints and UI hierarchy. No runtime side effects.
extends RefCounted

static func schema() -> Dictionary:
	return {
		"schema_format": 3,
		"settings_version": 1,
		"fields": {
			"duration": {
				"type": "int",
				"default": 180,
				"title": "比赛时限（秒）",
				"audience": "room",
				"apply": "next_round",
				"min": 30,
				"max": 600,
				"control": "number"
			},
			"hints": {
				"type": "int",
				"default": 3,
				"title": "每人提示次数",
				"audience": "room",
				"apply": "next_round",
				"min": 0,
				"max": 10,
				"control": "number"
			}
		},
		"layout": [
			{
				"id": "room",
				"title": "游戏规则",
				"expanded": true,
				"children": [
					{
						"field": "duration"
					},
					{
						"field": "hints"
					}
				]
			}
		]
	}
