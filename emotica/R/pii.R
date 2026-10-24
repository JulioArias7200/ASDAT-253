obtener_sal <- function(sal = NULL) {
  sal <- sal %si_vacio% Sys.getenv("EMOTICA_SAL", unset = NA_character_)
  if (is.na(sal) || !nzchar(sal)) {
    f <- ruta_recurso(".emotica_sal")
    if (file.exists(f)) sal <- readLines(f, n = 1, warn = FALSE) else {
      sal <- paste(sample(c(letters, 0:9), 32, replace = TRUE), collapse = "")
      writeLines(sal, f)
    }
  }
  sal
}

# Reemplaza nombre/id de autor por un hash con sal (SHA-256 recortado). Elimina nombres del resultado.
anonimizar_autores <- function(df, sal = NULL) {
  sal <- obtener_sal(sal)
  clave <- ifelse(!is.na(df$autor_id), df$autor_id, df$autor)
  clave[is.na(clave) | !nzchar(clave)] <- "anonimo"
  u <- unique(clave)
  h <- vapply(u, function(k) paste0("u_", substr(digest::digest(paste0(sal, k), algo = "sha256", serialize = FALSE), 1, 12)), "")
  df$autor_hash <- unname(h[clave])
  df$autor <- NULL; df$autor_id <- NULL
  attr(df, "detalle") <- sprintf("autores unicos=%d; nombres e ids originales eliminados de la tabla", length(u))
  df
}

.patrones_pii <- list(
  URL = "(?i)(https?://|www\\.)\\S+",
  EMAIL = "[\\w.+-]+@[\\w-]+\\.[\\w.-]+",
  USUARIO = "(?<![\\w])@\\w{3,}",
  NUM_ID = "(?<!\\d)(?:\\+\\d{1,3}[\\s-]?)?\\d{3,4}[\\s-]?\\d{4}(?!\\d)")

enmascarar_pii <- function(df) {
  cont <- c()
  for (n in names(.patrones_pii)) {
    cont[n] <- sum(stringi::stri_count_regex(df$texto, .patrones_pii[[n]]), na.rm = TRUE)
    df$texto <- stringi::stri_replace_all_regex(df$texto, .patrones_pii[[n]], paste0("<", n, ">"))
  }
  attr(df, "detalle") <- paste(names(cont), cont, sep = "=", collapse = "; ")
  df
}
