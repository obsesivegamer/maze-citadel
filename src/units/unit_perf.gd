class_name UnitPerf
extends RefCounted
## Unit and effect experiment switches, each a `--pf-<name>=<value>` flag (see
## PerfFlags). Defaults are the shipped look, so a run without flags renders
## exactly like the shipped game. Models are cached, so set them at launch.
##
## Towers:
##   tower-merge=<bool>           merge body surfaces whose materials match by
##                                value, not just by resource [false]
##   tower-shadow-parts=all|details|body
##                                which parts cast sun shadows: everything;
##                                not the ornaments (pennants, skulls, shards,
##                                spikes, rocks, crystals, coals); only the
##                                static body [all]
##   tower-lod=<bias>             0 off; > 0 generates mesh LODs for the merged
##                                body, uses a low-poly forge coal, hides the
##                                loaded bolt beyond 60 m × bias and sets
##                                GeometryInstance3D.lod_bias (< 1 = coarser) [0]
##   tower-idle-fx=on|near|off    idle particles (embers, notes, sparkles); near
##                                stops them while the camera is far out [on]
## Creeps:
##   creep-outline=stencil|body|off   team-colour silhouette pass on every
##                                mesh; only on skinned body meshes (not on
##                                helmets, shields, weapons); none (rim only) [stencil]
##   creep-status=overlay|emission    status washes as an extra additive pass,
##                                or folded into the creep material's emission [overlay]
##   creep-shadow=mesh|blob|off   skinned shadow casting, a soft blob under the
##                                feet instead, or none [mesh]
##   creep-anim-rate=<n>          advance animations every n-th frame [1]
## Effects:
##   fx-budget=<ratio>            amount scale for the large soft effects
##                                (smoke, clouds, flashes, fire, mist) [1.0]
##   fx-numbers=full|lite|off     damage numbers; lite drops the outline and
##                                fades without rebuilding the text mesh [full]

const IDLE_FX_FAR := 60.0
const BOLT_RANGE := 60.0


static func tower_merge() -> bool:
	return PerfFlags.get_bool("tower-merge", false)


static func tower_shadow_parts() -> String:
	return PerfFlags.get_str("tower-shadow-parts", "all")


static func tower_lod() -> float:
	return PerfFlags.get_float("tower-lod", 0.0)


static func tower_idle_fx() -> String:
	return PerfFlags.get_str("tower-idle-fx", "on")


static func creep_outline() -> String:
	return PerfFlags.get_str("creep-outline", "stencil")


static func creep_status() -> String:
	return PerfFlags.get_str("creep-status", "overlay")


static func creep_shadow() -> String:
	return PerfFlags.get_str("creep-shadow", "mesh")


static func creep_anim_rate() -> int:
	return maxi(PerfFlags.get_int("creep-anim-rate", 1), 1)


static func fx_budget() -> float:
	return clampf(PerfFlags.get_float("fx-budget", 1.0), 0.0, 1.0)


static func fx_numbers() -> String:
	return PerfFlags.get_str("fx-numbers", "full")
