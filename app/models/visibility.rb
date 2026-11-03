# Who can see what, in one place (replica/architecture.md, "Visibility rules").
# M1: anonymous readers see public; signed-in staff also see internal;
# superadmins also see private. Per-person/group accessors arrive in M2.
# "url_only" articles are never listed or searched, only opened by link.
module Visibility
  def self.listed(viewer)
    list = viewer&.active? ? %w[public internal] : %w[public]
    list << "private" if viewer&.superadmin?
    list
  end

  def self.by_link(viewer) = listed(viewer) + [ "url_only" ]
end
