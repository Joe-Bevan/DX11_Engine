# DirectX 11 Engine
The executable from my Advanced graphics and Real-time rendering module at Staffordshire university, programmed in C++.
## Current engine features
* Texturing of 3D objects *(each effect can dynamically enabled or disabled at runtime)*
  * Basic .dds texture support
  * Specular mapping
  * Normal mapping
  * Parallax occlusion mapping
* Directional lighting using the phong illumination model
  * Supports colored lights too!
* Shadow mapping
  * Each object can toggle if they cast shadows or not
* Post-processing pipeline support
  * Currently demoed using a box-blur shader
  * Can apply the effect to the UI if desired
* UI handeled by ImGui 
  * Learn more here: *https://github.com/ocornut/imgui*
* Each object can be viewed as a wireframe if desired

## Goals for the engine
* Implement a physics engine that I developed in my second year
* Add .obj file loading
* Add support for more file types
  * .objs for models
  * .png and .jpeg for textures
* Add scene support for easily swaping between scenes at runtime
