# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "three" # r170 standalone build, vendored (vendor/javascript/three.js)
pin "mannequin" # app/javascript/mannequin.js
pin "three/addons/loaders/GLTFLoader.js", to: "three-gltf-loader.js" # r170 examples/jsm, vendored
pin "three/addons/utils/BufferGeometryUtils.js", to: "three-buffer-geometry-utils.js"
pin "three/addons/exporters/GLTFExporter.js", to: "three-gltf-exporter.js" # r170 examples/jsm, vendored; dev video export only
pin "stage_figure" # app/javascript/stage_figure.js: video loop, live Mannequin fallback
