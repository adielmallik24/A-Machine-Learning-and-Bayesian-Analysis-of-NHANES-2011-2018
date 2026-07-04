# A-Machine-Learning-and-Bayesian-Analysis-of-NHANES-2011-2018
Predicting Low Muscle Mass in U.S. Adults: A Machine Learning and Bayesian Analysis of NHANES 2011–2018

CIND860 Capstone Project — Toronto Metropolitan University
Author: Adiel Mallik
Program: Practical Data Science and Machine Learning Graduate Certificate, Chang School for Continuing Education at Toronto Metropolitan University
 
Overview
Low muscle mass, defined here as an appendicular skeletal muscle mass index (ASMI) below the sex-specific 20th percentile, is a clinically relevant indicator of sarcopenia risk that remains underscreened in community settings. This project uses four NHANES survey cycles (2011–2018) to train and evaluate four machine learning classifiers: elastic net logistic regression, Random Forest, XGBoost, and support vector machine, alongside a Bayesian logistic regression fitted with brms. The machine learning pipeline includes SHAP-based explainability, subgroup fairness analysis, and interaction term testing. The Bayesian model provides posterior distributions for each predictor, prior sensitivity analysis across three prior specifications, and Bayes factors for the five strongest predictors. The dataset (n = 14,347 adults aged 20–59) draws on DXA-derived lean mass measurements, dietary recall, anthropometry, and socioeconomic variables from the CDC NHANES public release files.
 
Repository Structure
File	Description
NHANES_data_cleaning.R	Downloads raw NHANES modules via nhanesA, merges DXA, anthropometry, dietary, and grip strength data, derives ASMI and the binary outcome, and exports the cleaned dataset
NHANES_ML_analysis.Rmd	End-to-end ML pipeline: multiple imputation (MICE), BRI feature engineering, stratified train/test split, elastic net / Random Forest / XGBoost / SVM training with 5-fold CV, SHAP analysis, subgroup AUC, and interaction LRT
NHANES_Bayesian_analysis.Rmd	Bayesian logistic regression with brms: weakly informative priors encoding 20 % prevalence, prior sensitivity analysis (flat vs. Normal(0,0.5) vs. Normal(0,0.25)), MCMC diagnostics, posterior summaries, posterior predictive classification, and Bayes factors
nhanes_clean_2011_2018.csv	Cleaned analytical dataset (n = 14,347); exported by NHANES_data_cleaning.R
Mallik_CIND860_Capstone_LiteratureReview.docx	Literature review covering sarcopenia definitions, NHANES methodology, ML applications in body composition research, and Bayesian approaches in epidemiology
NHANES_ML_analysis.html	Compiled HTML output of the ML analysis Rmd
NHANES_Bayesian_analysis.html	Compiled HTML output of the Bayesian analysis Rmd
 Research Questions
1.	Which anthropometric, dietary, and socioeconomic predictors available in NHANES 2011–2018 are most strongly associated with low muscle mass (bottom sex-specific 20th percentile of ASMI) in adults aged 20–59?
2.	How do four machine learning classifiers (elastic net, Random Forest, XGBoost, SVM) compare in discriminating low muscle mass on a held-out test set, and does model performance vary by sex, age group, or race/ethnicity?
3.	What do Bayesian posterior distributions and Bayes factors reveal about the direction, magnitude, and uncertainty of predictor effects, and are these consistent across prior specifications?
 
Data Source
Attribute	Detail
Survey	NHANES 2011–2018 (CDC, National Center for Health Statistics)

Cycles	2011–12 (G), 2013–14 (H), 2015–16 (I), 2017–18 (J)
Modules	Demographics (DEMO), DXA body composition (DXX), anthropometry (BMX), 24-h dietary recall day 1 (DR1TOT), grip strength (MGX; 2011–14 only)
Age range	20–59 years
Analytic n	14,347 (after inner join on DXA availability and age filter)
Outcome	low_muscle_mass: 1 if ASMI < sex-specific 20th percentile, 0 otherwise
Access	Public use files freely available at https://wwwn.cdc.gov/nchs/nhanes/


DXA data were collected in mobile examination centres on a Hologic QDR 4500A fan-beam densitometer. Appendicular lean mass (ALM, kg) was computed as the sum of lean mass in both arms and both legs (DXXLALI + DXXRALI + DXXLLLI + DXXRLLI, converted from grams). ASMI was derived as ALM / height² (kg/m²).
 Methods Summary
•	Data cleaning and linkage: Raw NHANES modules downloaded via the nhanesA R package, merged on SEQN and survey cycle, filtered to adults 20–59 with complete DXA records. Sex-specific 20th-percentile ASMI thresholds computed from the merged sample.
•	Multiple imputation: Five variables with moderate missingness (poverty ratio, protein, energy, calcium, vitamin D) imputed using MICE (m = 10, method = PMM for all continuous targets). Outcome variables excluded from imputation. Pooling by averaging across imputed datasets.
•	Feature engineering: Body Roundness Index computed from the Thomas et al. (2013) formula using waist circumference and height. Decade-band age groups (20–29, 30–39, 40–49, 50–59). Protein intake winsorised at the sex-specific 99.5th percentile.
•	Train/test split: Stratified 70/30 split on low_muscle_mass (seed = 42) using caret::createDataPartition.
•	Machine learning models:  Four classifiers trained with 5-fold stratified cross-validation and class-weighted loss (inverse frequency weighting for elastic net, SVM, and Random Forest; scale_pos_weight for XGBoost). Evaluation metrics: AUC, F1 (macro), MCC, Sensitivity, Specificity, F2.
•	Explainability:  Native tree SHAP values for XGBoost; kernel SHAP via kernelshap for other models. Global beeswarm and bar plots, plus waterfall plots for one true positive, one false negative, and one false positive from the test set.
•	Subgroup analysis:  AUC, F1, and MCC stratified by sex, age group, and race/ethnicity on the held-out test partition.
•	Interaction testing:  Likelihood ratio tests comparing a base logistic model to models with added interaction terms between (sex, age group, race/ethnicity) and the top 5 SHAP predictors. Bonferroni correction applied.
•	Bayesian logistic regression: Fitted with brms (backend: RStan). Intercept prior: Normal(−1.39, 0.5) encoding the 20 % prevalence expectation. Coefficient priors: Normal(0, 0.5). Four chains × 4,000 iterations (2,000 warmup). Convergence assessed by R-hat and bulk/tail ESS. Prior sensitivity tested against flat-coefficient and Normal(0, 0.25) specifications. Bayes factors computed via the Savage–Dickey density ratio using bayestestR.
 Reproducing the Analysis
Requirements: R ≥ 4.3.0, RStudio ≥ 2023.09, RStan configured for your platform (see RStan Getting Started).
Step 1: Clone the repository
git clone https://github.com/adielmallik24/A-Machine-Learning-and-Bayesian-Analysis-of-NHANES-2011-2018.git
cd A-Machine-Learning-and-Bayesian-Analysis-of-NHANES-2011-2018

Step 2: Install R package dependencies
Run the following in an R console. Package versions are listed in the Dependencies section below.
install.packages(c(
  "nhanesA", "haven", "readxl", "writexl",
  "dplyr", "tidyr", "ggplot2", "forcats", "purrr",
  "mice", "caret", "glmnet", "randomForest", "xgboost",
  "kernlab", "pROC", "shapviz", "kernelshap",
  "brms", "bayesplot", "bayestestR", "posterior", "logspline",
  "gt", "knitr", "kableExtra", "gtsummary", "scales"
))

Step 3: Download and clean the data
Run NHANES_data_cleaning.R in full. This script downloads raw NHANES files from the CDC server (internet connection required), merges modules, derives the outcome variable, and writes nhanes_clean_2011_2018.xlsx and nhanes_clean_2011_2018.csv to the working directory. Runtime is approximately 5–10 minutes depending on connection speed.
source("NHANES_data_cleaning.R")

Alternatively, skip this step and use the pre-cleaned nhanes_clean_2011_2018.csv already in the repository.
Step 4: Run the ML analysis
Open NHANES_ML_analysis.Rmd in RStudio and knit to HTML (Ctrl+Shift+K). The Excel file (nhanes_clean_2011_2018.xlsx) must be in the same folder as the Rmd. The first knit caches model-training chunks; subsequent reruns are faster. Approximate runtime on a modern laptop: 30–60 minutes (first knit).
Step 5: Run the Bayesian analysis
Open NHANES_Bayesian_analysis.Rmd in RStudio and knit to HTML. RStan must be installed and functional before this step. The first knit fits four brms models sequentially; runtime on an Apple M1 Pro (10 cores) is approximately 40–65 minutes. On Intel hardware, expect 60–90 minutes.
Apple Silicon note: The Bayesian Rmd automatically writes -march=native -O3 to ~/.R/Makevars on first run, targeting the full ARM instruction set and reducing per-chain sampling time by approximately 15–25%.
 
Key R Package Dependencies
Package	Version tested	Purpose
nhanesA	1.1	NHANES data download
mice	3.16	Multiple imputation
caret	6.0-94	ML training and evaluation
glmnet	4.1-8	Elastic net logistic regression
randomForest	4.7-1.1	Random Forest
xgboost	1.7.7	Gradient boosted trees
kernlab	0.9-32	Support vector machine
shapviz	0.9.3	SHAP visualisation
kernelshap	0.5.0	Kernel SHAP for non-tree models
pROC	1.18.5	ROC and AUC computation
brms	2.21.0	Bayesian regression via Stan
bayesplot	1.11.1	MCMC diagnostics and plots
bayestestR	0.15.0	Posterior summaries and Bayes factors
logspline	2.1.21	Density estimation for Bayes factors
posterior	1.5.0	Posterior draw manipulation

Package versions can be confirmed after installation with packageVersion("<pkg>").
 
Author
Adiel Mallik
Department of Psychology / Ted Rogers School of Management
Toronto Metropolitan University
Toronto, Ontario, Canada
adiel.mallik@torontomu.ca
CIND860 Advanced Analytics Project
Supervisor: Professors Ashok Bowmich and Tamer Abdou
 
License
This repository is submitted as academic coursework. The cleaned dataset is derived from CDC NHANES public use files and is subject to the NCHS Data Use Agreement. All analysis code is released under the MIT License.
