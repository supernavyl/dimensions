## ProcAudio — generates AudioStreamWAV samples in code, no asset files needed.
## All generators return a looping mono 22050Hz stream unless noted.
class_name ProcAudio
extends RefCounted

const _SR: int = 22050


## High-pitched tinnitus ring. Mild beating from two close frequencies.
## duration_s controls loop length (longer = smoother).
static func tinnitus(duration_s: float = 2.0, gain: float = 0.18) -> AudioStreamWAV:
	var n: int = int(_SR * duration_s)
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	var f1: float = 4180.0
	var f2: float = 4205.0  # 25Hz beat
	for i: int in range(n):
		var t: float = float(i) / float(_SR)
		var sample: float = (sin(TAU * f1 * t) + sin(TAU * f2 * t) * 0.85) * 0.5
		# Slow tremolo
		sample *= 0.85 + 0.15 * sin(TAU * 0.6 * t)
		var pcm: int = int(clampf(sample * gain, -1.0, 1.0) * 32767.0)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	return _wrap(data, true)


## Single heartbeat thump. Two-stage thud (lub-dub) with low-frequency boom.
static func heartbeat(gain: float = 0.85) -> AudioStreamWAV:
	var dur: float = 0.55
	var n: int = int(_SR * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	for i: int in range(n):
		var t: float = float(i) / float(_SR)
		# Lub at t≈0.0, dub at t≈0.18, both ~80ms decay
		var lub: float = _thump(t, 0.0, 60.0, 0.09)
		var dub: float = _thump(t, 0.18, 75.0, 0.08) * 0.75
		var sample: float = (lub + dub) * gain
		var pcm: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	return _wrap(data, false)


## Brief click — for fluorescent on/off transitions.
## variant: 0 = sharp on-click, 1 = softer off-pop
static func fluorescent_click(variant: int = 0, gain: float = 0.5) -> AudioStreamWAV:
	var dur: float = 0.06
	var n: int = int(_SR * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i: int in range(n):
		var t: float = float(i) / float(_SR)
		var env: float = exp(-t * 70.0)
		var noise: float = rng.randf_range(-1.0, 1.0)
		var tone: float = sin(TAU * (1800.0 if variant == 0 else 320.0) * t)
		var sample: float = (noise * 0.55 + tone * 0.45) * env * gain
		var pcm: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	return _wrap(data, false)


## Low-frequency club bass thump for one beat. Loop at desired BPM externally.
static func club_thump(gain: float = 0.5) -> AudioStreamWAV:
	# 120 BPM = 0.5s per beat. Generate one beat.
	var dur: float = 0.5
	var n: int = int(_SR * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	for i: int in range(n):
		var t: float = float(i) / float(_SR)
		# Kick: 55Hz sine swept down to 40Hz over 80ms with sharp envelope
		var freq: float = lerpf(80.0, 42.0, clampf(t / 0.08, 0.0, 1.0))
		var env: float = exp(-t * 6.5)
		var sample: float = sin(TAU * freq * t) * env * gain
		var pcm: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	return _wrap(data, true)


## Fluorescent hum — 60Hz with harmonics, looped.
static func fluorescent_hum(gain: float = 0.07) -> AudioStreamWAV:
	var dur: float = 1.0  # exact second loops cleanly at 60Hz
	var n: int = int(_SR * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	for i: int in range(n):
		var t: float = float(i) / float(_SR)
		var sample: float = (
			sin(TAU * 60.0 * t) * 0.6
			+ sin(TAU * 120.0 * t) * 0.3
			+ sin(TAU * 180.0 * t) * 0.15
		) * gain
		var pcm: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	return _wrap(data, true)


## Footstep on hard tile — short noise burst with band-pass character.
## seed lets you generate variants so steps don't sound identical.
static func footstep(seed: int, gain: float = 0.4) -> AudioStreamWAV:
	var dur: float = 0.12
	var n: int = int(_SR * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# Two-pole resonator for the "tap" character.
	var prev: float = 0.0
	var prev2: float = 0.0
	var center: float = rng.randf_range(750.0, 1100.0)
	var omega: float = TAU * center / float(_SR)
	var r: float = 0.96
	var a1: float = 2.0 * r * cos(omega)
	var a2: float = -r * r
	for i: int in range(n):
		var t: float = float(i) / float(_SR)
		var env: float = exp(-t * 38.0) * (1.0 - exp(-t * 600.0))
		var noise: float = rng.randf_range(-1.0, 1.0)
		var x: float = noise * env
		var y: float = x + a1 * prev + a2 * prev2
		prev2 = prev
		prev = y
		var sample: float = y * gain
		var pcm: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	return _wrap(data, false)


## Body landing thud — heavier, lower, longer than a footstep.
static func land_thud(intensity: float = 1.0, gain: float = 0.7) -> AudioStreamWAV:
	var dur: float = 0.35
	var n: int = int(_SR * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	var k: float = clampf(intensity, 0.2, 1.5)
	for i: int in range(n):
		var t: float = float(i) / float(_SR)
		# Boom around 95Hz with slow decay
		var boom: float = sin(TAU * 95.0 * t) * exp(-t * 8.0)
		# Crack on top — quick high transient
		var crack: float = sin(TAU * 280.0 * t) * exp(-t * 28.0) * 0.5
		var sample: float = (boom + crack) * gain * k
		var pcm: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	return _wrap(data, false)


## Internal: damped thump at given start time.
static func _thump(t: float, t0: float, freq: float, decay: float) -> float:
	if t < t0:
		return 0.0
	var dt: float = t - t0
	return sin(TAU * freq * dt) * exp(-dt / decay)


static func _wrap(data: PackedByteArray, looping: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = _SR
	stream.stereo = false
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = data.size() / 2
	return stream
