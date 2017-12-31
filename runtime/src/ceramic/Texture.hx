package ceramic;

import ceramic.Assets;
import ceramic.Shortcuts.*;

using ceramic.Extensions;
using StringTools;

/** A texture is an image ready to be drawn. */
class Texture extends Entity {

/// Properties

    public var width(default,null):Float;

    public var height(default,null):Float;

    public var density(default,set):Float;
    function set_density(density:Float):Float {
        if (this.density == density) return density;
        this.density = density;
        width = app.backend.textures.getWidth(backendItem) / density;
        height = app.backend.textures.getHeight(backendItem) / density;
        return density;
    }

    public var backendItem:backend.Texture;

    public var asset:ImageAsset;

/// Lifecycle

    public function new(backendItem:backend.Texture, density:Float = 1) {

        this.backendItem = backendItem;
        this.density = density; // sets widht/height as well

    } //new

    public function destroy() {

        if (asset != null) asset.destroy();

        app.backend.textures.destroy(backendItem);
        backendItem = null;

    } //destroy

/// Print

    function toString():String {

        if (id != null) {
            var name = id;
            if (name.startsWith('texture:')) name = name.substr(8);
            return 'Texture($name $width $height $density)';
        } else {
            return 'Texture($width $height $density)';
        }

    } //toString

} //Texture
