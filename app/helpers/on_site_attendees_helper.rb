module OnSiteAttendeesHelper
  def leading_zero(num)
    num.to_s.strip.length == 1 ? "0#{num}" : num.to_s
  end

  def error_field(obj, field_name)
    return "has-error" if obj.errors[field_name].any?
  end
end