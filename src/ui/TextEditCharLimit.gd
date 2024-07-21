extends TextEdit

@export var char_limit : int = 130
var caret_line : int = 0
var caret_col : int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect("text_changed", _on_text_changed)

func limit_chars() -> void:
	if text.length() > char_limit:
		text = text.substr(0, char_limit)
		set_caret_line(caret_line)
		set_caret_column(caret_col)
	caret_line = get_caret_line()
	caret_col = get_caret_column()
	
func _on_text_changed() -> void:
	limit_chars()
