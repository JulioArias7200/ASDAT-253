test_that("to_state mapea indeterminado a neutro", {
  expect_equal(to_state(c("positivo", "negativo", "indeterminado")),
               c("positivo", "negativo", "neutro"))
})

test_that("build_transition_matrix normaliza filas y deja NA sin origen", {
  seq <- c("positivo", "negativo", "positivo", "positivo")
  tm <- build_transition_matrix(seq)
  expect_equal(sum(tm$P["positivo", ], na.rm = TRUE), 1)
  expect_equal(unname(tm$counts["positivo", "negativo"]), 1)
})

test_that("stationary_distribution suma 1 en cadenas ergódicas", {
  P <- matrix(c(0.5, 0.3, 0.2,
                0.2, 0.6, 0.2,
                0.3, 0.3, 0.4), nrow = 3, byrow = TRUE,
              dimnames = list(c("positivo", "negativo", "neutro"),
                              c("positivo", "negativo", "neutro")))
  pi <- stationary_distribution(P)
  expect_equal(sum(pi), 1, tolerance = 1e-6)
})

test_that("mean_first_passage devuelve 0 si ya está absorbido", {
  P <- matrix(c(0.5, 0.5, 0.5, 0.5), nrow = 2,
              dimnames = list(c("positivo", "negativo"), c("positivo", "negativo")))
  expect_equal(mean_first_passage(P, "positivo", c("positivo"), c("positivo", "negativo")), 0)
})

test_that("markov_analysis devuelve estructura completa", {
  cfg <- load_config()
  df <- tibble::tibble(
    ts = as.POSIXct("2023-01-01 00:00:00", tz = "UTC") + 0:9,
    sender_id = rep("u1", 10),
    polarity_label = c("positivo", "positivo", "negativo", "neutro", "positivo",
                       "negativo", "negativo", "neutro", "positivo", "positivo"))
  mk <- markov_analysis(df, cfg)
  expect_true(all(c("states", "results", "sequence") %in% names(mk)))
  r <- mk$results[[1]]
  expect_true(all(c("P", "stationary", "residence", "recovery") %in% names(r)))
  expect_lte(sum(r$stationary, na.rm = TRUE), 1 + 1e-6)
})
