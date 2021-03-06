#' Write a ply format for MorphoGraphX from a mesh3D R object
#'
#' @param mesh A 3D (triangular) mesh object.
#' @param filename The name we want to give to the created .ply file.
#' @param label_it_for_mesh Triangle color.
#'
#' @importFrom dplyr as_tibble bind_cols mutate
#' @importFrom glue collapse
#' @importFrom parallel detectCores
#' @importFrom purrr map
#' @importFrom snow makeCluster parApply stopCluster
#' @importFrom utils write.table
#' @export
#' @return a .ply file readable by MorphoGraphX

mesh2ply <- function(mesh = mesh,
                             filename = "my_ply.ply",
                             label_it_for_mesh = mesh$label_it){

  #1. Triangles

  # checking that triangles are unique (by ordering and gluing vertex labels together)
  unique_it <- unique(unlist(map(.x = 1:ncol(mesh$it),
                                        ~ collapse(sort(mesh$it[,.]), sep = "_") )))
  if(length(unique_it) < ncol(mesh$it)){
    warning("Mesh has duplicated triangles.")
  }

  triangles_IDs <- t(mesh$it) %>%
    -1 %>%
    as_tibble(.) %>%
    bind_cols(meshtype = rep(3, nrow(.)), .) %>%
    mutate(., label = label_it_for_mesh)


  #2. Vertices

  triangles_label <- rbind( cbind( mesh$it[1,]-1, label_it_for_mesh ),
                            cbind( mesh$it[2,]-1, label_it_for_mesh ),
                            cbind( mesh$it[3,]-1, label_it_for_mesh ) )

  cl <- makeCluster(detectCores() - 1)
  res <- parApply(cl, triangles_label, 1, function(i){ paste(i[1], i[2], sep = "_") })
  stopCluster(cl)

  # vertices with associated label (label is expected to be a numeric)
  res2 <- matrix(as.numeric(unlist(strsplit( unique(res), split = "_"))), byrow = TRUE, ncol = 2)

  # Repeated vertices will receive label -1
  rep_vb_ind <- which(table(res2[,1]) > 1)
  row_ind <- res2[,1] %in% rep_vb_ind # elements that are repeated (TRUE) or not (FALSE)
  res2[row_ind, 2] <- -1

  # Missing vertices (not associated to a triangle), will also receive label -1

  all_vertices_from_it <- unique(c( mesh$it[1,]-1,
                                    mesh$it[2,]-1,
                                    mesh$it[3,]-1))
  all_vertices_from_vb <- 1:ncol(mesh$vb)-1
  single_vb <- setdiff(all_vertices_from_vb, all_vertices_from_it)

  label_vb_tmp <- rbind(res2,
                        cbind(single_vb, rep(-1, length(single_vb))))
  label_vb <- label_vb_tmp[order(label_vb_tmp[,1]),]

  vertex_coord <- cbind( format(mesh$vb[1,], scientific = FALSE) # format has to be applied column by column
                         ,format(mesh$vb[2,], scientific = FALSE)
                         ,format(mesh$vb[3,], scientific = FALSE)
                         ,format(label_vb[,2], scientific = FALSE)
  )

  #3. Writing ply file # for the moment removed   cat("property float signal\n")
  sink(file = filename)

  cat("ply\n")
  cat("format ascii 1.0\n")
  cat("element vertex", nrow(vertex_coord), "\n")
  cat("property float x\n")
  cat("property float y\n")
  cat("property float z\n")
  cat("property int label\n")
  cat("element face", nrow(triangles_IDs), "\n") #cat("element face", length(itSUB), "\n") #
  cat("property list uchar int vertex_index\n")
  cat("property int label\n")
  cat("end_header\n")
  sink()
  options(scipen=10)
  write.table(x = vertex_coord, file = filename, append = TRUE, sep = " ", row.names = FALSE, col.names = FALSE, quote = FALSE) #quote = FALSE is very important since we force the format to character to avoid the scientific notation
  write.table(x = triangles_IDs, file = filename, append = TRUE, sep = " ", row.names = FALSE, col.names = FALSE, quote = FALSE)
  options(scipen=0)
}

