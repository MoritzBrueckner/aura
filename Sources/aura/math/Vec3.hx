package aura.math;

import kha.FastFloat;
import kha.math.FastVector3;
import kha.math.FastVector4;

@:forward
abstract Vec3(FastVector3) from FastVector3 to FastVector3 {
	public inline function new(x: FastFloat = 0.0, y: FastFloat = 0.0, z: FastFloat = 0.0) {
		this = new FastVector3(x, y, z);
	}

	@:from
	public static inline function fromKhaVec3(v: kha.math.FastVector3): Vec3 {
		return new FastVector3(v.x, v.y, v.z);
	}

	@:from
	public static inline function fromKhaVec4(v: kha.math.FastVector4): Vec3 {
		return new FastVector3(v.x, v.y, v.z);
	}

	@:to
	public inline function toKhaVec3(): kha.math.FastVector3 {
		return new FastVector3(this.x, this.y, this.z);
	}

	@:to
	public inline function toKhaVec4(): kha.math.FastVector4 {
		return new FastVector4(this.x, this.y, this.z);
	}

	#if (AURA_WITH_IRON || armory)
	@:from
	public static inline function fromIronVec3(v: iron.math.Vec3): Vec3{
		return new FastVector3(v.x, v.y, v.z);
	}

	@:from
	public static inline function fromIronVec4(v: iron.math.Vec4): Vec3{
		return new FastVector3(v.x, v.y, v.z);
	}

	@:to
	public inline function toIronVec3(): iron.math.Vec3 {
		return new iron.math.Vec3(this.x, this.y, this.z);
	}

	@:to
	public inline function toIronVec4(): iron.math.Vec4 {
		return new iron.math.Vec4(this.x, this.y, this.z);
	}
	#end
}
