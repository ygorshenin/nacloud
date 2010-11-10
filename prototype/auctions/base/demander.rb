# Author: Yuri Gorshenin

class Demander
  def initialize(demander_id)
    @demander_id = demander_id
  end

  def get_id
    @demander_id
  end

  def to_s
    "#@demander_id"
  end
end
