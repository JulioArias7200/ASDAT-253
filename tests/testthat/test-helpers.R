test_that("proj_path se ancla a la raíz del proyecto", {
  p <- proj_path("R", "helpers.R")
  expect_true(file.exists(p))
})

test_that("%||% devuelve el primer valor no nulo", {
  expect_equal(NULL %||% "b", "b")
  expect_equal("a" %||% "b", "a")
})

test_that("hash_string y anon_id son deterministas y estables", {
  expect_equal(hash_string("x"), hash_string("x"))
  expect_false(identical(hash_string("x"), hash_string("y")))
  expect_equal(anon_id("user12345"), anon_id("user12345"))
  expect_true(grepl("^u_[0-9a-f]{8}$", anon_id("user12345")))
})

test_that("to_nfc normaliza unicode", {
  decomp <- "e\u0301"
  expect_equal(to_nfc(decomp), "\u00e9")
})

test_that("now_utc tiene formato ISO-8601 UTC", {
  expect_true(grepl("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", now_utc()))
})

test_that("code_version no está vacío", {
  expect_true(nzchar(code_version()))
})
