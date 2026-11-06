module ExercisesHelper
  # Motion JSON for the figure/thumb controllers; category tints the joints.
  def motion_json(exercise) = exercise.motion.merge("category" => exercise.category).to_json

  def thumb_tag(exercise, key: 0, size: 240, **opts)
    tag.img(src: "data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==", alt: opts.delete(:alt) || exercise.name, width: size / 2, height: size / 2, class: [ "thumb", opts.delete(:class) ],
            data: { controller: "thumb", thumb_motion_value: motion_json(exercise), thumb_key_value: key, thumb_size_value: size }, **opts)
  end
end
