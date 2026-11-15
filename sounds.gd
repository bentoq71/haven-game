
class_name Sounds
extends RefCounted
## Procedurally generated sound effects.

const RATE := 22050


static func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


static func _blank(seconds: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(RATE * seconds))
	return s


static func tick() -> AudioStreamWAV:
	var s := _blank(0.12)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = (sin(TAU * 1800.0 * t) * 0.4 + randf_range(-1.0, 1.0) * 0.3) * exp(-t * 60.0)
	return _wav(s)


static func step() -> AudioStreamWAV:
	var s := _blank(0.1)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = (sin(TAU * 85.0 * t) * 0.8 + randf_range(-1.0, 1.0) * 0.2) * exp(-t * 35.0)
	return _wav(s)


static func chime() -> AudioStreamWAV:
	var s := _blank(0.9)
	for i in s.size():
		var t := float(i) / RATE
		var v := sin(TAU * 880.0 * t) + 0.5 * sin(TAU * 1320.0 * t) + 0.25 * sin(TAU * 1760.0 * t)
		s[i] = v * exp(-t * 4.0) * 0.35
	return _wav(s)


## Echo pulse
static func echo() -> AudioStreamWAV:
	var s := _blank(1.0)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := lerpf(900.0, 180.0, t)
		phase += TAU * f / RATE
		s[i] = (sin(phase) * 0.6 + sin(phase * 2.01) * 0.2) * exp(-t * 3.5)
	return _wav(s)


## Recollection ability
static func recollect() -> AudioStreamWAV:
	var s := _blank(0.9)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := lerpf(180.0, 700.0, t / 0.9)
		phase += TAU * f / RATE
		var env := sin(PI * t / 0.9)
		var trem := 0.7 + 0.3 * sin(TAU * 12.0 * t)
		s[i] = sin(phase) * env * trem * 0.5
	return _wav(s)


## Watcher sound
static func stinger() -> AudioStreamWAV:
	var s := _blank(1.4)
	for i in s.size():
		var t := float(i) / RATE
		var v := sin(TAU * 45.0 * t) * 0.6 + sin(TAU * 47.0 * t) * 0.4
		v += randf_range(-1.0, 1.0) * 0.5 * exp(-t * 5.0)
		s[i] = v * exp(-t * 2.5)
	return _wav(s)


## Dialogue blip
static func blip() -> AudioStreamWAV:
	var s := _blank(0.05)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = sin(TAU * 520.0 * t) * exp(-t * 55.0) * 0.5
	return _wav(s)
