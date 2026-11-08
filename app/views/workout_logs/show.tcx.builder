start = @log.performed_at.utc.iso8601
xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.TrainingCenterDatabase xmlns: "http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2",
                           "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance" do
  xml.Activities do
    xml.Activity Sport: "Other" do
      xml.Id start
      xml.Lap StartTime: start do
        xml.TotalTimeSeconds @log.duration_seconds
        xml.DistanceMeters 0
        xml.Calories @log.kcal.to_i
        if (avg = @log.heart_rate(:avg_hr))
          xml.AverageHeartRateBpm { xml.Value avg }
        end
        if (max = @log.heart_rate(:max_hr))
          xml.MaximumHeartRateBpm { xml.Value max }
        end
        xml.Intensity "Active"
        xml.TriggerMethod "Manual"
      end
      xml.Notes [ @log.workout_name, @log.exercises.map(&:name).join(", "), ("RPE #{@log.rpe}/10" if @log.rpe), "via Shichimi" ].compact_blank.join(" · ")
    end
  end
end
