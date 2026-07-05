# =============================================================================
# NHANES 2011-2018: Data Cleaning & Exploratory Data Analysis
# Capstone Project - CIND860 / Toronto Metropolitan University
# Author: Adiel Mallik
# Date: June 2026
# =============================================================================

library(nhanesA)
library(haven)
library(dplyr)
library(tidyr)
library(ggplot2)
library(writexl)
library(gtsummary)

# ── 1. Download NHANES modules ────────────────────────────────────────────────

fetch_module <- function(module, suffix) {
  year_val <- switch(suffix, "G" = 2011, "H" = 2013, "I" = 2015, "J" = 2017)
  df <- nhanes(paste0(module, "_", suffix), translated = FALSE)
  df$year <- year_val
  df
}

demo <- bind_rows(fetch_module("DEMO","G"), fetch_module("DEMO","H"),
                  fetch_module("DEMO","I"), fetch_module("DEMO","J"))

dxa  <- bind_rows(fetch_module("DXX","G"),  fetch_module("DXX","H"),
                  fetch_module("DXX","I"),  fetch_module("DXX","J"))

bmx  <- bind_rows(fetch_module("BMX","G"),  fetch_module("BMX","H"),
                  fetch_module("BMX","I"),  fetch_module("BMX","J"))

diet <- bind_rows(fetch_module("DR1TOT","G"), fetch_module("DR1TOT","H"),
                  fetch_module("DR1TOT","I"), fetch_module("DR1TOT","J"))

grip <- bind_rows(fetch_module("MGX","G"), fetch_module("MGX","H"))

# ── 2. Select, rename, and coerce variables ───────────────────────────────────

demo_sel <- demo %>%
  select(SEQN, year, RIDAGEYR, RIAGENDR, RIDRETH3, INDFMPIR) %>%
  rename(age_years     = RIDAGEYR,
         sex_code      = RIAGENDR,
         race_code     = RIDRETH3,
         poverty_ratio = INDFMPIR) %>%
  mutate(across(c(age_years, sex_code, race_code, poverty_ratio), as.numeric))

dxa_sel <- dxa %>%
  select(SEQN, year, DXXLALI, DXXRALI, DXXLLLI, DXXRLLI) %>%
  mutate(across(c(DXXLALI, DXXRALI, DXXLLLI, DXXRLLI), as.numeric))

bmx_sel <- bmx %>%
  select(SEQN, year, BMXBMI, BMXWT, BMXHT, BMXWAIST) %>%
  rename(bmi = BMXBMI, weight_kg = BMXWT, height_cm = BMXHT, waist_cm = BMXWAIST) %>%
  mutate(across(c(bmi, weight_kg, height_cm, waist_cm), as.numeric))

diet_sel <- diet %>%
  select(SEQN, year, DR1TKCAL, DR1TPROT, DR1TCALC, DR1TVD) %>%
  rename(energy_kcal   = DR1TKCAL,
         protein_g     = DR1TPROT,
         calcium_mg    = DR1TCALC,
         vitamin_d_mcg = DR1TVD) %>%
  mutate(across(c(energy_kcal, protein_g, calcium_mg, vitamin_d_mcg), as.numeric))

grip_sel <- grip %>%
  select(SEQN, year, MGXH1T1, MGXH1T2, MGXH1T3, MGXH2T1, MGXH2T2, MGXH2T3) %>%
  mutate(across(c(MGXH1T1, MGXH1T2, MGXH1T3, MGXH2T1, MGXH2T2, MGXH2T3), as.numeric),
         max_grip_kg = pmax(MGXH1T1, MGXH1T2, MGXH1T3,
                            MGXH2T1, MGXH2T2, MGXH2T3, na.rm = TRUE)) %>%
  select(SEQN, year, max_grip_kg)

# ── 3. Merge ──────────────────────────────────────────────────────────────────

nhanes <- demo_sel %>%
  inner_join(dxa_sel,  by = c("SEQN", "year")) %>%
  inner_join(bmx_sel,  by = c("SEQN", "year")) %>%
  left_join(diet_sel,  by = c("SEQN", "year")) %>%
  left_join(grip_sel,  by = c("SEQN", "year")) %>%
  filter(age_years >= 20 & age_years <= 59)

cat("Merged dataset:", nrow(nhanes), "adults aged 20-59\n")
print(table(nhanes$year))

# ── 4. Derive analytical variables ───────────────────────────────────────────

nhanes <- nhanes %>%
  mutate(
    sex = case_when(sex_code == 1 ~ "Male",
                    sex_code == 2 ~ "Female",
                    TRUE          ~ NA_character_),
    race_ethnicity = case_when(
      race_code == 1 ~ "Mexican American",
      race_code == 2 ~ "Other Hispanic",
      race_code == 3 ~ "Non-Hispanic White",
      race_code == 4 ~ "Non-Hispanic Black",
      race_code == 6 ~ "Non-Hispanic Asian",
      race_code == 7 ~ "Other/Multiracial",
      TRUE           ~ NA_character_
    ),
    alm_kg   = (DXXLALI + DXXRALI + DXXLLLI + DXXRLLI) / 1000,
    height_m = height_cm / 100,
    asmi     = alm_kg / height_m^2
  )

male_p20   <- quantile(nhanes$asmi[nhanes$sex == "Male"],   0.20, na.rm = TRUE)
female_p20 <- quantile(nhanes$asmi[nhanes$sex == "Female"], 0.20, na.rm = TRUE)

cat("Male ASMI 20th pct:  ", round(male_p20,   2), "kg/m^2\n")
cat("Female ASMI 20th pct:", round(female_p20, 2), "kg/m^2\n")

nhanes <- nhanes %>%
  mutate(
    low_muscle_mass = case_when(
      sex == "Male"   & asmi <  male_p20   ~ 1L,
      sex == "Male"   & asmi >= male_p20   ~ 0L,
      sex == "Female" & asmi <  female_p20 ~ 1L,
      sex == "Female" & asmi >= female_p20 ~ 0L,
      TRUE ~ NA_integer_
    ),
    low_grip = case_when(
      sex == "Male"   & max_grip_kg <  27 ~ 1L,
      sex == "Male"   & max_grip_kg >= 27 ~ 0L,
      sex == "Female" & max_grip_kg <  16 ~ 1L,
      sex == "Female" & max_grip_kg >= 16 ~ 0L,
      TRUE ~ NA_integer_
    )
  )

# ── 5. Outlier flags ──────────────────────────────────────────────────────────

nhanes <- nhanes %>%
  mutate(
    bmi_outlier     = if_else(bmi         > 60,   1L, 0L, missing = NA_integer_),
    protein_outlier = if_else(protein_g   > 300,  1L, 0L, missing = NA_integer_),
    energy_outlier  = if_else(energy_kcal > 8000, 1L, 0L, missing = NA_integer_)
  )

cat("BMI > 60:          ", sum(nhanes$bmi_outlier,     na.rm = TRUE), "\n")
cat("Protein > 300g:    ", sum(nhanes$protein_outlier, na.rm = TRUE), "\n")
cat("Energy > 8000 kcal:", sum(nhanes$energy_outlier,  na.rm = TRUE), "\n")

# ── 6. Missing data summary ───────────────────────────────────────────────────

key_vars <- c("asmi", "alm_kg", "max_grip_kg", "bmi", "weight_kg", "height_cm",
              "waist_cm", "poverty_ratio", "protein_g", "energy_kcal",
              "calcium_mg", "vitamin_d_mcg")

miss_summary <- data.frame(
  variable    = key_vars,
  n_missing   = sapply(nhanes[key_vars], function(x) sum(is.na(x))),
  pct_missing = sapply(nhanes[key_vars], function(x) round(mean(is.na(x)) * 100, 1))
)
print(miss_summary)

# ── 7. Descriptive statistics table ──────────────────────────────────────────

nhanes_tbl <- nhanes %>% filter(!is.na(sex))

tbl_summary(
  data = nhanes_tbl,
  include = c(age_years, bmi, asmi, alm_kg, max_grip_kg,
              protein_g, energy_kcal, low_muscle_mass, low_grip),
  by = sex,
  statistic = list(all_continuous()  ~ "{mean} ({sd})",
                   all_categorical() ~ "{n} ({p}%)"),
  digits = list(all_continuous() ~ 2),
  label = list(
    age_years       ~ "Age (years)",
    bmi             ~ "BMI (kg/m2)",
    asmi            ~ "ASMI (kg/m2)",
    alm_kg          ~ "ALM (kg)",
    max_grip_kg     ~ "Max Grip Strength (kg)",
    protein_g       ~ "Protein Intake (g/day)",
    energy_kcal     ~ "Energy Intake (kcal/day)",
    low_muscle_mass ~ "Low Muscle Mass (n, %)",
    low_grip        ~ "Low Grip Strength (n, %)"
  )
) %>%
  add_overall() %>%
  add_p() %>%
  bold_labels()

# ── 8. EDA Plots ──────────────────────────────────────────────────────────────

# Figure 1: ASMI density by sex
p1 <- ggplot(nhanes %>% filter(!is.na(sex), !is.na(asmi)),
             aes(x = asmi, fill = sex, colour = sex)) +
  geom_density(alpha = 0.20, linewidth = 0.9) +
  scale_fill_manual(values   = c("Male" = "#3B82F6", "Female" = "#EF4444")) +
  scale_colour_manual(values = c("Male" = "#3B82F6", "Female" = "#EF4444")) +
  labs(title   = "ASMI Distribution by Sex (NHANES 2011-2018)",
       x = "ASMI (kg/m2)", y = "Density",
       caption = "Source: CDC NHANES | Outcome = bottom 20th %ile ASMI by sex") +
  theme_bw(base_size = 13)
ggsave("fig1_asmi_density.png", p1, width = 8, height = 5, dpi = 150)

# Figure 2: Low muscle mass prevalence by age group and sex
p2 <- nhanes %>%
  filter(!is.na(sex), !is.na(low_muscle_mass)) %>%
  mutate(age_group = cut(age_years, breaks = c(20, 30, 40, 50, 60),
                         labels = c("20-29","30-39","40-49","50-59"),
                         right = FALSE)) %>%
  group_by(age_group, sex) %>%
  summarise(pct_lmm = mean(low_muscle_mass, na.rm = TRUE) * 100, .groups = "drop") %>%
  ggplot(aes(x = age_group, y = pct_lmm, fill = sex)) +
  geom_col(position = "dodge") +
  geom_text(aes(label = sprintf("%.1f%%", pct_lmm)),
            position = position_dodge(width = 0.9), vjust = -0.4, size = 3.5) +
  scale_fill_manual(values = c("Male" = "#3B82F6", "Female" = "#EF4444")) +
  ylim(0, 30) +
  labs(title = "Low Muscle Mass Rate by Age Group and Sex",
       x = "Age Group", y = "Prevalence (%)",
       caption = "Source: NHANES 2011-2018") +
  theme_bw(base_size = 13)
ggsave("fig2_lmm_age_sex.png", p2, width = 8, height = 5, dpi = 150)

# Figure 3: ASMI vs grip strength scatter
set.seed(42)
p3_data <- nhanes %>%
  filter(!is.na(asmi), !is.na(max_grip_kg), !is.na(sex))
p3_n <- min(1500, nrow(p3_data))

p3 <- p3_data %>%
  slice_sample(n = p3_n) %>%
  ggplot(aes(x = asmi, y = max_grip_kg, colour = sex)) +
  geom_point(alpha = 0.35, size = 1.8) +
  geom_smooth(method = "lm", se = TRUE, linewidth = 1.1) +
  scale_colour_manual(values = c("Male" = "#3B82F6", "Female" = "#EF4444")) +
  labs(title   = "Grip Strength vs ASMI by Sex (NHANES 2011-2018)",
       x = "ASMI (kg/m2)", y = "Max Grip Strength (kg)",
       caption = "Linear regression with 95% CI shown") +
  theme_bw(base_size = 13)
ggsave("fig3_asmi_grip_scatter.png", p3, width = 8, height = 5, dpi = 150)

# Figure 4: Missing data overview
p4 <- miss_summary %>%
  arrange(pct_missing) %>%
  mutate(variable = factor(variable, levels = variable)) %>%
  ggplot(aes(x = pct_missing, y = variable)) +
  geom_col(fill = "#3B82F6") +
  geom_text(aes(label = paste0(pct_missing, "%")), hjust = -0.1, size = 3.5) +
  xlim(0, 65) +
  labs(title   = "Missing Data by Variable (NHANES 2011-2018)",
       x = "Missing (%)", y = "",
       caption = "DXA not collected for all participants; grip not in 2015-2018") +
  theme_bw(base_size = 13)
ggsave("fig4_missing_data.png", p4, width = 8, height = 5, dpi = 150)

# ── 9. Export clean dataset ────────────────────────────────────────────────────

nhanes_export <- nhanes %>%
  select(SEQN, year, age_years, sex, race_ethnicity, poverty_ratio,
         bmi, weight_kg, height_cm, waist_cm,
         alm_kg, asmi, max_grip_kg,
         protein_g, energy_kcal, calcium_mg, vitamin_d_mcg,
         low_muscle_mass, low_grip,
         bmi_outlier, protein_outlier, energy_outlier) %>%
  rename(participant_id = SEQN, survey_cycle = year)

write_xlsx(nhanes_export, "nhanes_clean_2011_2018.xlsx")
write.csv(nhanes_export,  "nhanes_clean_2011_2018.csv", row.names = FALSE)

cat("\nExport complete:", nrow(nhanes_export), "rows,",
    ncol(nhanes_export), "columns\n")
cat("Low muscle mass prevalence:",
    round(mean(nhanes_export$low_muscle_mass, na.rm = TRUE) * 100, 1), "%\n")