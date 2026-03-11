module ApplicationHelper
  def nav_link(text, path, _icon, active = false)
    css = active ? "bg-indigo-50 text-indigo-600" : "text-gray-700 hover:bg-gray-50 hover:text-indigo-600"

    content_tag(:li) do
      link_to text, path, class: "group flex gap-x-3 rounded-md p-2 text-sm font-semibold #{css}"
    end
  end

  def status_badge(status)
    colors = {
      "online" => "bg-green-100 text-green-700",
      "offline" => "bg-gray-100 text-gray-700",
      "busy" => "bg-red-100 text-red-700",
      "on_break" => "bg-yellow-100 text-yellow-700",
      "queued" => "bg-blue-100 text-blue-700",
      "answered" => "bg-green-100 text-green-700",
      "completed" => "bg-gray-100 text-gray-700",
      "abandoned" => "bg-red-100 text-red-700",
      "failed" => "bg-red-100 text-red-700"
    }

    content_tag(:span, status.humanize,
      class: "inline-flex items-center rounded-full px-2 py-1 text-xs font-medium #{colors[status] || 'bg-gray-100 text-gray-700'}")
  end
end
