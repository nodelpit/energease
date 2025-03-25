module ApplicationHelper
  def flash_class(type)
    case type.to_sym
    when :alert, :error
      "bg-red-100 border-l-4 border-red-500 text-red-700"
    when :warning
      "bg-yellow-100 border-l-4 border-yellow-500 text-yellow-700"
    when :notice, :success
      "bg-green-100 border-l-4 border-green-500 text-green-700"
    else
      "bg-blue-100 border-l-4 border-blue-500 text-blue-700"
    end
  end
end
