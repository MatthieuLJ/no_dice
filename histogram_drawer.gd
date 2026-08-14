extends Control

var pmf: Dictionary = {}
var target_sum: int = -1
var is_broken: bool = false

func set_data(p_pmf: Dictionary, p_target_sum: int, p_is_broken: bool) -> void:
	pmf = p_pmf
	target_sum = p_target_sum
	is_broken = p_is_broken
	queue_redraw()

func _draw() -> void:
	var rect_size = get_rect().size
	if rect_size.x <= 0 or rect_size.y <= 0:
		return

	# Draw background panel
	var bg_rect = Rect2(Vector2.ZERO, rect_size)
	draw_rect(bg_rect, Color(0.02, 0.08, 0.04, 0.75), true)
	draw_rect(bg_rect, Color(0.1, 0.4, 0.2, 0.6), false, 2.0)

	if is_broken:
		var font = get_theme_default_font()
		if font:
			draw_string(font, Vector2(rect_size.x * 0.5 - 60, rect_size.y * 0.5), "Broken Die!", HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color(1.0, 0.3, 0.3))
		return

	if pmf.is_empty():
		return

	var keys = pmf.keys()
	keys.sort()

	var min_sum: int = int(keys[0])
	var max_sum: int = int(keys[-1])
	var num_bars: int = max_sum - min_sum + 1

	var max_prob: float = 0.0001
	for k in keys:
		var p = float(pmf[k])
		if p > max_prob:
			max_prob = p

	var padding_left: float = 16.0
	var padding_right: float = 16.0
	var padding_top: float = 32.0
	var padding_bottom: float = 32.0

	var chart_w: float = rect_size.x - padding_left - padding_right
	var chart_h: float = rect_size.y - padding_top - padding_bottom

	var bar_total_w: float = chart_w / float(max(1, num_bars))
	var bar_gap: float = clampf(bar_total_w * 0.15, 1.0, 4.0)
	var bar_w: float = max(1.0, bar_total_w - bar_gap)

	var font = get_theme_default_font()

	# Grid lines (25%, 50%, 75%, 100% of max_prob)
	for i in range(1, 4):
		var ratio = float(i) / 4.0
		var y_pos = padding_top + chart_h * (1.0 - ratio)
		draw_line(Vector2(padding_left, y_pos), Vector2(rect_size.x - padding_right, y_pos), Color(0.2, 0.4, 0.3, 0.25), 1.0)

	# Draw Bars
	for i in range(num_bars):
		var s: int = min_sum + i
		var prob: float = float(pmf.get(s, 0.0))
		var h_ratio: float = clampf(prob / max_prob, 0.0, 1.0)
		var bar_h: float = chart_h * h_ratio

		var x_pos: float = padding_left + float(i) * bar_total_w + (bar_gap * 0.5)
		var y_pos: float = padding_top + (chart_h - bar_h)

		var bar_rect = Rect2(x_pos, y_pos, bar_w, bar_h)
		var is_highlight: bool = (s == target_sum)

		if is_highlight:
			# Golden glowing highlight for the actual rolled sum
			draw_rect(bar_rect, Color(1.0, 0.85, 0.2, 0.95), true)
			draw_rect(bar_rect, Color(1.0, 1.0, 0.7, 1.0), false, 2.0)

			# Top glow marker line
			draw_line(Vector2(x_pos - 2, y_pos), Vector2(x_pos + bar_w + 2, y_pos), Color(1.0, 0.95, 0.4, 1.0), 3.0)

			# Percentage label above bar if space permits
			if font and bar_w >= 10:
				var pct_str = "%.1f%%" % (prob * 100.0)
				draw_string(font, Vector2(x_pos - 10, max(18.0, y_pos - 6.0)), pct_str, HORIZONTAL_ALIGNMENT_CENTER, int(bar_w + 20), 13, Color(1.0, 0.9, 0.3))
		else:
			# Dark forest cyan/emerald for non-rolled bars
			draw_rect(bar_rect, Color(0.1, 0.55, 0.35, 0.75), true)
			draw_rect(bar_rect, Color(0.2, 0.75, 0.45, 0.5), false, 1.0)

		# X-axis label for min_sum, max_sum, target_sum, and step ticks
		var show_label: bool = false
		if num_bars <= 20:
			show_label = true
		else:
			show_label = (s == min_sum or s == max_sum or s == target_sum or (s % 5 == 0))

		if show_label and font:
			var label_col = Color(1.0, 0.85, 0.2) if is_highlight else Color(0.6, 0.9, 0.7, 0.8)
			var lbl_y = rect_size.y - padding_bottom + 18.0
			draw_string(font, Vector2(x_pos - 8, lbl_y), str(s), HORIZONTAL_ALIGNMENT_CENTER, int(bar_w + 16), 12, label_col)
