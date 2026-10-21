class AddNotes {
  bool validateTitle(String title) {
    if (title.trim().isEmpty) {
      return false;
    }
    return true;
  }
}
