/// Lightweight DTO for Leistung dropdown items in the Member edit dialog.
///
/// Decouples the Members feature from the Leistungen feature module (Issue 4.2).
/// Contains only the fields needed for dropdown selection and auto-fill.
class LeistungDropdownItem {
  final int id;
  final String name;
  final double bruttopreis;

  const LeistungDropdownItem({
    required this.id,
    required this.name,
    required this.bruttopreis,
  });
}
