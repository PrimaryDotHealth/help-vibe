module AnalyticsHelper
  # One chart: all searches as quiet bars, no-answer searches as the one
  # accent line (S19). Server-rendered SVG, no chart library.
  def searches_chart(series, dead_series, width: 1000, height: 280)
    left, right, top, bottom = 40, 8, 12, 28
    max = [ series.map(&:last).max.to_i, 4 ].max
    max = (max * 1.15).ceil
    plot_w, plot_h = width - left - right, height - top - bottom
    bw = plot_w.to_f / series.size
    y = ->(v) { top + plot_h * (1 - v.to_f / max) }
    ticks = [ 0, max / 4, max / 2, max * 3 / 4, max ].uniq
    labels = series.each_with_index.select { |(_d, _v), i| i % [ (series.size / 5.0).ceil, 1 ].max == 0 }

    tag.svg(viewBox: "0 0 #{width} #{height}", class: "chart", style: "height:auto", role: "img",
            "aria-label": "Searches per day, with searches that found no answer as a line") do
      grid = ticks.map { tag.line(x1: left, x2: width - right, y1: y.(_1).round(1), y2: y.(_1).round(1)) }
      axis = ticks.map { tag.text(_1, x: left - 8, y: (y.(_1) + 4).round(1), "text-anchor": "end") } +
             labels.map { |(d, _), i| tag.text(d.strftime("%-d %b"), x: (left + bw * i + bw / 2).round(1), y: height - 8, "text-anchor": "middle") }
      bars = series.each_with_index.map do |(d, v), i|
        tag.rect(x: (left + bw * i + bw * 0.18).round(1), y: y.(v).round(1), width: (bw * 0.64).round(1),
                 height: (y.(0) - y.(v)).round(1), rx: 2) { tag.title("#{d.strftime("%-d %b")}: #{v} searches") }
      end
      points = dead_series.each_with_index.map { |(_d, v), i| "#{(left + bw * i + bw / 2).round(1)},#{y.(v).round(1)}" }
      safe_join([
        tag.g(safe_join(grid), class: "grid"), tag.g(safe_join(axis), class: "axis"),
        tag.g(safe_join(bars), fill: "var(--line-strong)"),
        tag.polyline(points: points.join(" "), fill: "none", stroke: "var(--ink)", "stroke-width": 2, "stroke-linejoin": "round", "stroke-linecap": "round")
      ])
    end
  end

  def change_vs(now, before, unit: "%")
    return tag.span("No earlier data", class: "t3") if before.nil? || now.nil?
    diff = now - before
    return tag.span("Same as the previous period", class: "t3") if diff.zero?
    tag.span(safe_join([ tag.b("#{diff.positive? ? "+" : ""}#{diff}#{unit}"), " vs the previous period" ]))
  end
end
