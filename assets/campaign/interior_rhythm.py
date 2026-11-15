"""Short terrain changes on long walks without changing room joins."""


def break_up_walk(name, start, end, y, variant, level, slope, *, low_ceiling=False):
    """Preserve the takeoff and landing at either end of a traversal span."""
    length = end - start
    count = int(length >= 19.5) + int(length >= 37) + int(length >= 55)
    if not count:
        level(name, start, end, y)
        return
    at = start
    for index in range(count):
        style = (variant + index) % 4
        center = start + length * (index + 1) / (count + 1)
        half_width = (3.1, 3.65, 3.4, 3.15)[style]
        left, right = center - half_width, center + half_width
        level(name + ("" if index == 0 else "Level" + str(index)), at, left, y)
        rise = (.83, 1.12, -.65, .90)[style] if not low_ceiling else -.65
        up, down = center - (1.15 if style == 0 else .60), center + (.65 if style != 1 else 1.45)
        slope(name + "GradeIn" + str(index), left, up, y, y + rise)
        level(name + "Bench" + str(index), up, down, y + rise)
        slope(name + "GradeOut" + str(index), down, right, y + rise, y)
        at = right
    level(name + "Rejoin", at, end, y)
