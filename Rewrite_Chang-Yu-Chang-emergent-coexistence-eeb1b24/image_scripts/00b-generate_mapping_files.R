library(tidyverse)
library(jsonlite)  # For parsing JSON files

source(here::here("processing_scripts/00-metadata.R"))

# 确保输出目录存在
output_dir <- "image_scripts/mapping_files/"
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# 遍历每一个批次
for (j in 1:length(batch_names)) {
    folder_original <- paste0(folder_pipeline, "images/", batch_names[j], "-00-original/")
    image_names <- list.files(folder_original, pattern = ".tiff") %>% str_replace(".tiff", "")

    # 初始化 image_name 和对应文件夹的映射表
    n_images <- length(image_names)
    list_images <- tibble(
        image_name = image_names,
        folder_original = rep(paste0(folder_pipeline, "images/", batch_names[j], "-00-original/"), n_images),
        folder_channel = rep(paste0(folder_pipeline, "images/", batch_names[j], "-", list_folders[1], "/"), n_images),
        folder_rolled = rep(paste0(folder_pipeline, "images/", batch_names[j], "-", list_folders[2],"/"), n_images),
        folder_threshold = rep(paste0(folder_pipeline, "images/", batch_names[j], "-", list_folders[3], "/"), n_images),
        folder_round = rep(paste0(folder_pipeline, "images/", batch_names[j], "-", list_folders[4], "/"), n_images),
        folder_watershed = rep(paste0(folder_pipeline, "images/", batch_names[j], "-", list_folders[5], "/"), n_images),
        folder_transect = rep(paste0(folder_pipeline, "images/", batch_names[j], "-", list_folders[6], "/"), n_images),
        folder_feature = rep(paste0(folder_pipeline, "images/", batch_names[j], "-", list_folders[7], "/"), n_images),
        folder_random_forest = rep(paste0(folder_pipeline, "images/", batch_names[j], "-", list_folders[8], "/"), n_images),
        folder_bootstrap = rep(paste0(folder_pipeline, "images/", batch_names[j], "-", list_folders[9], "/"), n_images),
        folder_combined = rep(paste0(folder_pipeline, "images/", batch_names[j], "-", list_folders[10], "/"), n_images)
    )

    # Repeat the rows 3 times for rgb channels
    for (color in c("red", "green", "blue")) {
        file_path <- paste0(output_dir, "00-list_images-", batch_names[j], "-", color, ".csv")
        list_images %>%
            mutate(color_channel = color) %>%
            select(image_name, color_channel, everything()) %>%
            write_csv(file_path)
        cat("\n", file_path, " created")
    }

    # Initialize list to store pairs and isolates information
    pair_annotations <- vector("list", length = 0)
    isolate_annotations <- vector("list", length = 0)
    
    # Process each image based on annotations
    for (image_name in image_names) {
        # Read the corresponding JSON file for annotations
        json_file <- paste0(folder_original, image_name, ".json")
        if (!file.exists(json_file)) {
            cat("\n", "Warning: JSON file", json_file, " does not exist. Skipping this file.")
            next
        }
        
        # Parse JSON file
        annotations <- tryCatch({
            fromJSON(json_file)
        }, error = function(e) {
            cat("\n", "Error in parsing JSON file:", json_file, "\nError message:", e$message)
            return(NULL)
        })
        
        if (is.null(annotations)) next
        
        classes <- annotations$classes
        
        # Depending on the number of classes, classify the image
        if (length(classes) == 2) {
            # It's a pair image
            pair_annotations <- append(pair_annotations, list(tibble(
                image_name_pair = image_name,
                isolate_type_1 = classes[1],
                isolate_type_2 = classes[2]
            )))
        } else if (length(classes) == 1) {
            # It's an isolate image
            isolate_annotations <- append(isolate_annotations, list(tibble(
                image_name_isolate = image_name,
                isolate_type = classes[1]
            )))
        }
    }
    
    # Bind rows to create data frames from lists of tibbles
    pair_annotations <- bind_rows(pair_annotations)
    isolate_annotations <- bind_rows(isolate_annotations)

    # Create an empty tibble to store the final mapping
    final_mapping <- tibble(
        image_name_pair = character(),
        image_name_isolate1 = character(),
        image_name_isolate2 = character()
    )

    # Process each unique pair type to match isolates
    for (pair_type in unique(paste(pair_annotations$isolate_type_1, pair_annotations$isolate_type_2, sep = ", "))) {
        # Extract and sort the pair images of this type
        current_pairs <- pair_annotations %>%
            filter(paste(isolate_type_1, isolate_type_2, sep = ", ") == pair_type) %>%
            pull(image_name_pair) %>%
            sort()
        
        # Extract the two isolate types from the pair type
        isolates <- str_split(pair_type, ", ", simplify = TRUE)
        isolate1_type <- isolates[1]
        isolate2_type <- isolates[2]

        # Get the isolate images of each type and sort them
        isolate1_images <- isolate_annotations %>%
            filter(isolate_type == isolate1_type) %>%
            pull(image_name_isolate) %>%
            sort()
        isolate2_images <- isolate_annotations %>%
            filter(isolate_type == isolate2_type) %>%
            pull(image_name_isolate) %>%
            sort()
        
        # Match pair images with corresponding isolates
        for (k in seq_along(current_pairs)) {
            final_mapping <- final_mapping %>%
                add_row(
                    image_name_pair = current_pairs[k],
                    image_name_isolate1 = isolate1_images[k],
                    image_name_isolate2 = isolate2_images[k]
                )
        }
    }

    # Write the mapping to file
    write_csv(final_mapping, paste0(output_dir, "00-list_image_mapping-", batch_names[j], ".csv"))
    cat("\n", paste0(output_dir, "00-list_image_mapping-", batch_names[j], ".csv"), " created")
}

# 2. Merge the mapping files to create a master mapping csv ----
list_images_master <- list()
list_image_mapping_master <- list()
for (j in 1:length(batch_names)) {
    list_images_master[[j]] <- read_csv(paste0(output_dir, "00-list_images-", batch_names[j], "-green.csv"), show_col_types = FALSE)
    list_image_mapping_master[[j]] <- read_csv(paste0(output_dir, "00-list_image_mapping-", batch_names[j], ".csv"), show_col_types = FALSE)
}
list_images_master <- bind_rows(list_images_master)
list_image_mapping_master <- bind_rows(list_image_mapping_master)

write_csv(list_image_mapping_master, paste0(output_dir, "00-list_image_mapping_folder_master.csv"))
cat("\n", paste0(output_dir, "00-list_image_mapping_folder_master.csv"), " created")
