IG_TTT = "Tenured or tenure-track instructor"
IG_OTH = "Other primary instructor, such as adjunct, visiting, honorarium, etc."
IG_TA = "Teaching_Assistant"

class Instructor < ActiveRecord::Base
# attr_accessor :instructor_first, :instructor_last
self.per_page = 10

  searchable do 
    text :instructor_first
    text :instructor_last, :default_boost => 2
  end

  belongs_to :department
  has_many :fcqs
  # has_many :courses
  has_many :courses, -> { distinct }, through: :fcqs

  validates_uniqueness_of :instructor_first, scope: [:instructor_last]
  #instrrespect
  #availability
  #instreffective
  #overall
  #passrate
  #classes taught
  #students taught
  #records since

  def name
    return "#{self.instructor_first.titleize}, #{self.instructor_last.titleize}"
  end

  def full_name
  	return name.split.map(&:capitalize).join(' ')
  end

  def instructor_object
    return %Q{#{college}}
  end

  def campus
      #currently defaults to string literal. This should be changed!
    "CU Boulder"
  end

  def department_string
    if department == nil
      return "--"
    else 
      return department.name
    end
  end

  def instr_group
    return self.data['instructor_group'] || "TTT"
  end

  def is_TA
    return (instr_group == "TA") ? true : false
  end

  def instructor_type_string
    is_TA ? "teaching assistant" : "instructor"
  end

  def overall_from_course(c)
    subject = c.subject
    crse = c.crse
    set = self.fcqs.where("subject = ? AND crse = ?", subject, crse)
    return set.average(:instructoroverall).round(1)
  end

  def started_teaching
    return self.data['earliest_class'].to_i
  end

  def latest_teaching
    return self.data['latest_class'].to_i
  end

  def average_instrrespect
    x = self.data['average_instructor_respect'].to_f || 0.0
    return x.round(1)
  end

  def average_availability
    x = self.data['average_instructor_availability'].to_f || 0.0
    return x.round(1)
  end

  def average_instreffective
    x = self.data['average_instructor_effectiveness'].to_f || 0.0
    return x.round(1)
  end

  def total_requested
    self.fcqs.sum(:formsrequested) 
  end

  def total_returned
    self.fcqs.sum(:formsreturned)
  end


  def requested_returned_ratio
     (total_returned.to_f / total_requested.to_f).round(1)
  end

  def average_instructoroverall
    overall = self.data['average_instructor_overall'].to_f || 0.0
    return overall.round(1)
  end

  def courses_taught
    count = (self.data['courses_taught']).to_i
    return [count,1].max
  end

  attr_reader :semesters, :overall_data, :availability_data, :instrrespect_data, :instreffective_data, :overall_average, :availability_average, :instrrespect_average, :instreffective_average


  ########################################
  # This is where we use the grade csv   #
  ########################################

  def average_percentage_passed_float
    return self.data["average_percent_passed"].to_f
  end

  def compute_average_percentage_passed
    total = 0.0
    self.fcqs.compact.each {|x| next if x.float_passed < 0.0; total += x.float_passed}
    count = courses_taught
    if count == 0
      return 1.0 
    else
      return (total.to_f / count.to_f)
    end
  end
  
  def pass_rate_string
    pp = average_percentage_passed_float || 0.0
    val = (pp * 100).round(1)
    val = [val, 100].min
    val = [val, 0].max
    string = val.round 
    return "#{string}%"
  end 

  # these take the avg grades of all classes taught by a prof and avg them 
  def average_grade_overall
    return self.data["average_grade"]
  end

    # these take the avg grades of all classes taught by a prof and avg them 
  def compute_average_grade
    total = 0.0
    self.fcqs.compact.each {|x| next if x.avg_grd == nil; total += x.avg_grd}
    count = courses_taught
    if count == 0
      return 1.0 
    else
      return (total.to_f / count.to_f)
    end
  end

  ##################End grades.csv stuff#####################


  def overall_query
    @overall_data = self.data['overall_data']
    @availability_data = self.data['availability_data']
    @instreffective_data = self.data['instreffective_data']
    @instrrespect_data = self.data['instrrespect_data']
    @overall_average = self.department.data['average_instructoroverall']
    @availability_average = self.department.data['average_availability']
    @instrrespect_average = self.department.data['average_instrrespect']
    @instreffective_average = self.department.data['average_instreffective']
  end

  def build_hstore
    overalls = self.fcqs.order("yearterm").group("yearterm").average(:instructoroverall)
    avails = self.fcqs.order("yearterm").group("yearterm").average(:availability)
    effects = self.fcqs.order("yearterm").group("yearterm").average(:instreffective)
    instrrespects = self.fcqs.order("yearterm").group("yearterm").average(:instrrespect)
    @semesters = []
    @overall_data = []
    @availability_data = [] 
    @instrrespect_data = [] 
    @instreffective_data = [] 
    #records.each {|k,v| fixedrecords[Fcq.semterm_from_int(k)] = v.to_f.round(1)}
    overalls.each {|k,v| @overall_data << [k,v.to_f.round(1)]}
    avails.each {|k,v| @availability_data << [k,v.to_f.round(1)]}
    effects.each {|k,v| @instreffective_data << [k,v.to_f.round(1)]}
    instrrespects.each {|k,v| @instrrespect_data << [k,v.to_f.round(1)]}
    self.data = {}
    self.data['overall_data'] = @overall_data
    self.data['availability_data'] = @availability_data
    self.data['instreffective_data'] = @instreffective_data
    self.data['instrrespect_data'] = @instrrespect_data
    self.data['courses_taught'] = self.fcqs.where('pct_c_minus_or_below IS NOT NULL').count
    self.data['average_grade'] = compute_average_grade
    self.data['average_percent_passed'] =compute_average_percentage_passed
    self.data['average_instructor_overall'] = self.fcqs.average(:instructoroverall)
    self.data['average_instructor_effectiveness'] = self.fcqs.average(:instreffective)
    self.data['average_instructor_respect'] = self.fcqs.average(:instrrespect)
    self.data['average_instructor_availability'] = self.fcqs.average(:availability)
    self.data['latest_class'] = self.fcqs.maximum(:yearterm)
    self.data['earliest_class'] = self.fcqs.minimum(:yearterm)
    self.data['instructor_group'] = self.fcqs.pluck(:instr_group).mode
    self.save
  end


  def instr_group_flavor_text
    case instr_group
    when "TTT" 
      return IG_TTT
    when "OTH"
      return IG_OTH
    when "TA"
      return IG_TA
    else
      return "ERROR! Flavor text not found"
    end
  end

  def color
      if is_TA
        return "box6"
      else
        return "box4"
      end
  end

end
