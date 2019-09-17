package ceramic;

class Tween extends Entity {

/// Static helpers

    public static function start(#if ceramic_optional_owner ?owner:Entity #else owner:Entity #end, ?id:Int, ?easing:TweenEasing, duration:Float, fromValue:Float, toValue:Float, handleValueTime:Float->Float->Void):Tween {

        var instance = new Tween(owner, id, easing == null ? TweenEasing.QUAD_EASE_IN_OUT : easing, duration, fromValue, toValue);
        
        instance.onUpdate(null, handleValueTime);

        return instance;

    } //start

/// Events

    @event function update(value:Float, time:Float);

    @event function complete();

/// Properties

    var actuator:motion.actuators.GenericActuator<UpdateFloat>;

    var target:UpdateFloat;

    var startTime:Float;

/// Lifecycle

    private function new(#if ceramic_optional_owner ?owner:Entity #else owner:Entity #end, ?id:Int, easing:TweenEasing, duration:Float, fromValue:Float, toValue:Float) {

        super();

        if (duration == 0.0) {
            App.app.onceImmediate(function() {
                emitUpdate(toValue, 0);
                emitComplete();
                destroy();
            });
            return;
        }
        
        var _owner = owner;

        var actuateEasing = Tween.actuateEasing(easing);

        var actuateDuration = duration;
        
        startTime = Timer.now;
        target = new UpdateFloat(fromValue);
        actuator = motion.Actuate.tween(target, actuateDuration, { value: toValue }, false);

        actuator.onComplete(function() {
            if (destroyed) return;
            if (_owner != null && _owner.destroyed) {
                destroy();
                return;
            }
            emitComplete();
            destroy();
        });

        actuator.onUpdate(function() {
            if (destroyed) return;
            if (_owner != null && _owner.destroyed) {
                destroy();
                return;
            }
            var time = Timer.now - startTime;
            var value = target.value;
            emitUpdate(value, time);
        });

        actuator.ease(actuateEasing);

    } //new

    override function destroy() {

        super.destroy();

        if (target != null) {
            motion.Actuate.stop(target);
            actuator = null;
            target = null;
        }

    } //destroy

/// Helpers

    public static function actuateEasing(easing:TweenEasing) {

        return switch (easing) {

            case LINEAR: motion.easing.Linear.easeNone;

            case BACK_EASE_IN: motion.easing.Back.easeIn;
            case BACK_EASE_IN_OUT: motion.easing.Back.easeInOut;
            case BACK_EASE_OUT: motion.easing.Back.easeOut;

            case QUAD_EASE_IN: motion.easing.Quad.easeIn;
            case QUAD_EASE_IN_OUT: motion.easing.Quad.easeInOut;
            case QUAD_EASE_OUT: motion.easing.Quad.easeOut;

            case BOUNCE_EASE_IN: motion.easing.Bounce.easeIn;
            case BOUNCE_EASE_IN_OUT: motion.easing.Bounce.easeInOut;
            case BOUNCE_EASE_OUT: motion.easing.Bounce.easeOut;

            case CUBIC_EASE_IN: motion.easing.Cubic.easeIn;
            case CUBIC_EASE_IN_OUT: motion.easing.Cubic.easeInOut;
            case CUBIC_EASE_OUT: motion.easing.Cubic.easeOut;

            case ELASTIC_EASE_IN: motion.easing.Elastic.easeIn;
            case ELASTIC_EASE_IN_OUT: motion.easing.Elastic.easeInOut;
            case ELASTIC_EASE_OUT: motion.easing.Elastic.easeOut;

            case EXPO_EASE_IN: motion.easing.Expo.easeIn;
            case EXPO_EASE_IN_OUT: motion.easing.Expo.easeInOut;
            case EXPO_EASE_OUT: motion.easing.Expo.easeOut;

            case QUART_EASE_IN: motion.easing.Quart.easeIn;
            case QUART_EASE_IN_OUT: motion.easing.Quart.easeInOut;
            case QUART_EASE_OUT: motion.easing.Quart.easeOut;

            case QUINT_EASE_IN: motion.easing.Quint.easeIn;
            case QUINT_EASE_IN_OUT: motion.easing.Quint.easeInOut;
            case QUINT_EASE_OUT: motion.easing.Quint.easeOut;

            case SINE_EASE_IN: motion.easing.Sine.easeIn;
            case SINE_EASE_IN_OUT: motion.easing.Sine.easeInOut;
            case SINE_EASE_OUT: motion.easing.Sine.easeOut;

            case BEZIER(x1, y1, x2, y2): new ActuateCustomEasing(new BezierEasing(x1, y1, x2, y2).ease);

            case CUSTOM(easing): new ActuateCustomEasing(easing);

        }

    } //actuateEasing

    public static function easingFunction(easing:TweenEasing):Float->Float {

        return actuateEasing(easing).calculate;

    } //easingFunction

} //Tween

@:allow(ceramic.Tween)
private class UpdateFloat {

    public var value:Float = 0;

    public function new(value:Float) {

        this.value = value;

    } //new
    
} //UpdateFloat

class ActuateCustomEasing implements motion.easing.IEasing {

    var customEasing:Float->Float;

	public function new(customEasing:Float->Float) {

        this.customEasing = customEasing;
		
	} //new

	public function calculate(k:Float):Float {
		return customEasing(k);
	}

	public function ease(t:Float, b:Float, c:Float, d:Float):Float {
		return c * t / d + b;
	}

} //ActuateCustomEasing
