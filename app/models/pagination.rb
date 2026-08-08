# Slices a relation into a page and exposes what a numbered pager needs. Runs a
# COUNT on construction to know the last page, then clamps the requested page
# into range. Plain object, not persisted; built via
# ApplicationController#paginate.
class Pagination
  attr_reader :page, :per_page, :total

  def initialize(scope, page:, per_page:)
    @scope = scope
    @per_page = per_page
    @total = scope.count
    @page = page.clamp(1, pages)
  end

  # The relation for the current page (still lazy; the view materialises it).
  def records
    @records ||= @scope.limit(per_page).offset((page - 1) * per_page)
  end

  # Total number of pages, at least 1 even when empty.
  def pages
    return 1 if total.zero?

    (total.to_f / per_page).ceil
  end

  def prev? = page > 1
  def next? = page < pages

  # Page numbers to render: page 1, the last page, and up to +around+ pages
  # either side of the current page, with :gap markers where pages are skipped,
  # e.g. [1, :gap, 4, 5, 6, 7, 8, :gap, 12].
  def series(around: 2)
    nearby = ([ page - around, 1 ].max..[ page + around, pages ].min).to_a
    shown = [ 1, *nearby, pages ].uniq.sort
    shown.each_with_object([]) do |number, series|
      series << :gap if series.last.is_a?(Integer) && number - series.last > 1
      series << number
    end
  end
end
