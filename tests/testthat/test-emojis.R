test_that("has_emoji distingue textos con y sin emoji", {
  expect_equal(has_emoji(c("hola", "feliz \U0001F60A")), c(FALSE, TRUE))
  expect_false(has_emoji(NA_character_))
})

test_that("process_emojis extrae emojis y devuelve vector para entrada escalar", {
  emo <- process_emojis("Estoy muy feliz \U0001F60A")
  expect_true("\U0001F60A" %in% emo)
  lst <- process_emojis(c("a \U0001F60A", "sin emoji"))
  expect_type(lst, "list")
  expect_length(lst, 2)
  expect_true("\U0001F60A" %in% lst[[1]])
  expect_length(lst[[2]], 0)
})

test_that("strip_emojis elimina emojis del texto", {
  expect_equal(strip_emojis("hola \U0001F60A mundo"), "hola  mundo")
})

test_that("emoji_signal puntúa emojis del diccionario", {
  dict <- test_dictionary()
  pos <- emoji_signal(process_emojis("\U0001F60A"), dict)
  neg <- emoji_signal(process_emojis("\U0001F622"), dict)
  expect_gt(pos$score, 0)
  expect_lt(neg$score, 0)
  expect_true("tristeza" %in% names(neg$emotions))
})

test_that("parse_emoji_list tolera NA y JSON vacío", {
  expect_length(parse_emoji_list(NA_character_), 0)
  expect_length(parse_emoji_list("[]"), 0)
  expect_equal(parse_emoji_list('["\U0001F60A"]'), "\U0001F60A")
})
