
EasyML is easy enough to figure it out by yourself! Just run the following lines. 
These are all the functions you will probably ever need.

## Settings up
```julia
hardware_resources.allow_GPU = true
hardware_resources.num_cores = 4
graphics.scaling_factor = 1
```

## Design
```julia
modify_classes()
modify_output()
design_model()
```

## Train
```julia
modify(training_options)
get_urls_training()
get_urls_testing()
prepare_training_data()
prepare_testing_data()
results = train()
remove_training_data()
remove_testing_data()
remove_training_results()
```

## Validate
```julia
get_urls_validation()
results = validate()
remove_validation_data()
remove_validation_results()
```

## Apply
```julia
modify(application_options)
get_urls_application()
apply()
remove_application_data()
```

## On reopening
```julia
load_model()
load_settings()
```