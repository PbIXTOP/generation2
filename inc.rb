require 'json'

class String
  def is_json?
    begin
    !!JSON.parse(self)
    rescue
    false
    end
  end
end

class Object
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end

  def present?
    !blank?
  end
end