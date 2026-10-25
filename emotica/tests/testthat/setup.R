if (!exists("preprocess_chat")) {
  root <- normalizePath(file.path("..", ".."))
  options(emotica.raiz = root)
  for (f in list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE)) source(f, encoding = "UTF-8")
}
