
#---Channels
# 
@with_kw struct Channels
    training_data_progress::Channel = Channel{Float32}(Inf)
    training_data_results::Channel = Channel{Any}(1)
    training_data_modifiers::Channel = Channel{Any}(Inf)
    training_progress::Channel = Channel{Any}(Inf)
    training_results::Channel = Channel{Any}(Inf)
    training_modifiers::Channel = Channel{Any}(Inf)
    validation_data_progress::Channel = Channel{Float32}(Inf)
    validation_data_results::Channel = Channel{Any}(1)
    validation_data_modifiers::Channel = Channel{Any}(Inf)
    validation_progress::Channel = Channel{Any}(Inf)
    validation_results::Channel = Channel{Any}(Inf)
    validation_modifiers::Channel = Channel{Any}(Inf)
    training_labels_colors::Channel = Channel{Any}(Inf)
    application_data_progress::Channel = Channel{Any}(Inf)
    application_data_results::Channel = Channel{Any}(1)
    application_progress::Channel = Channel{Any}(Inf)
    application_modifiers::Channel = Channel{Any}(Inf)
end
channels = Channels()

#---Model data

abstract type AbstractFeature end

@with_kw mutable struct Output_mask
    mask::Bool = false
    mask_border::Bool = false
    mask_applied_border::Bool = false
end

@with_kw mutable struct Output_area
    area_distribution::Bool = false
    obj_area::Bool = false
    obj_area_sum::Bool = false
    binning::Int64 = 0
    value::Float64 = 10
    normalisation::Int64 = 0
end

@with_kw mutable struct Output_volume
    volume_distribution::Bool = false
    obj_volume::Bool = false
    obj_volume_sum::Bool = false
    binning::Int64 = 0
    value::Float64 = 10
    normalisation::Int64 = 0
end

@with_kw mutable struct Segmentation_output_options
    Mask::Output_mask = Output_mask()
    Area::Output_area = Output_area()
    Volume::Output_volume = Output_volume()
end

@with_kw mutable struct Segmentation_feature<:AbstractFeature
    name::String = ""
    color::Vector{Float64} = Vector{Float64}(undef,3)
    border::Bool = false
    border_thickness::Int64 = 3
    border_remove_objs::Bool = false
    min_area::Int64 = 1
    parents::Vector{String} = ["",""]
    not_feature::Bool = false
    Output::Segmentation_output_options = Segmentation_output_options()
end
segmentation_feature = Segmentation_feature()

@with_kw mutable struct Classification_feature<:AbstractFeature
    name::String = ""
end
classification_feature = Classification_feature()

@with_kw mutable struct Model_data
    input_size::Tuple{Int64,Int64,Int64} = (160,160,1)
    model::Chain = Chain()
    layers::Vector{Dict{String,Any}} = []
    features::Vector{<:AbstractFeature} = Vector{Classification_feature}(undef,0)
    loss::Function = Flux.Losses.crossentropy
end
model_data = Model_data()

#---Master data
@with_kw mutable struct Training_plot_data
    data_input::Vector{Array{Float32,3}} = Vector{Array{Float32,3}}(undef,0)
    data_labels::Vector{BitArray{3}} = Vector{BitArray{3}}(undef,0)
    iteration::Int64 = 0
    epoch::Int64 = 0
    iterations_per_epoch::Int64 = 0
    starting_time::DateTime = now()
    max_iterations::Int64 = 0
    learning_rate_changed::Bool = false
end
training_plot_data = Training_plot_data()

@with_kw mutable struct Training_results_data
    loss::Union{Vector{Float32},Vector{Float64}} = Vector{Float32}(undef,0)
    accuracy::Union{Vector{Float32},Vector{Float64}} = Vector{Float32}(undef,0)
    test_accuracy::Union{Vector{Float32},Vector{Float64}} = Vector{Float32}(undef,0)
    test_loss::Union{Vector{Float32},Vector{Float64}} = Vector{Float32}(undef,0)
    test_iteration::Vector{Int64} = Vector{Int64}(undef,0)
end
training_results_data = Training_results_data()

@with_kw mutable struct Training_data
    Plot_data::Training_plot_data = training_plot_data
    Results::Training_results_data = training_results_data
    input_urls::Vector{String} = Vector{String}(undef,0)
    label_urls::Vector{String} = Vector{String}(undef,0)
    foldernames::Vector{String} = Vector{String}(undef,0)
    filenames::Vector{Vector{String}} = Vector{Vector{String}}(undef,0)
    fileindices::Vector{Vector{Int64}} = Vector{Vector{Int64}}(undef,0)
end
training_data = Training_data()

@with_kw mutable struct Validation_results
    original::Vector{Array{RGB{N0f8},2}} = 
        Vector{Array{RGB{N0f8},2}}(undef,0)
    predicted_data::Vector{Vector{Tuple{BitArray{2},Vector{N0f8}}}} = 
        Vector{Vector{Tuple{BitArray{2},Vector{N0f8}}}}(undef,0)
    target_data::Vector{Vector{Tuple{BitArray{2},Vector{N0f8}}}} = 
        Vector{Vector{Tuple{BitArray{2},Vector{N0f8}}}}(undef,0)
    error_data::Vector{Vector{Tuple{BitArray{3},Vector{N0f8}}}} = 
        Vector{Vector{Tuple{BitArray{3},Vector{N0f8}}}}(undef,0)
    other_data::Vector{Tuple{Float32,Float32}} = 
        Vector{Tuple{Float32,Float32}}(undef,0)
end
validation_results = Validation_results()

@with_kw mutable struct Validation_data
    Results::Validation_results = validation_results
    input_urls::Vector{String} = Vector{String}(undef,0)
    label_urls::Vector{String} = Vector{String}(undef,0)
end
validation_data = Validation_data()

@with_kw mutable struct Application_data
    input_urls::Vector{Vector{String}} = Vector{Vector{String}}(undef,0)
    folders::Vector{String} = Vector{String}(undef,0)
end
application_data = Application_data()

@with_kw mutable struct Master_data
    Training_data::Training_data = training_data
    Validation_data::Validation_data = validation_data
    Application_data::Application_data = application_data
    image::Array{RGB{Float32},2} = Array{RGB{Float32},2}(undef,0,0)
end
master_data = Master_data()

#---Settings
# Main
@with_kw mutable struct Main_s
    a::Int = 0
end
main = Main_s()

# Options
@with_kw mutable struct Hardware_resources
    allow_GPU::Bool = true
    num_cores::Int64 = Threads.nthreads()
end
hardware_resources = Hardware_resources()
@with_kw mutable struct Options
    Hardware_resources::Hardware_resources = hardware_resources
end
options = Options()

# Training
@with_kw mutable struct Processing_training
    mirroring::Bool = true
    num_angles::Int64 = 2
    min_fr_pix::Float64 = 0.1
end
processing_training = Processing_training()

@with_kw mutable struct Hyperparameters_training
    optimiser::Tuple{String,Int64} = ("ADAM",5)
    optimiser_params::Vector{Vector{Float64}} = [[],[0.9],[0.9],[0.9],
      [0.9,0.999],[0.9,0.999],[0.9,0.999],[],[0.9],[0.9,0.999],
      [0.9,0.999],[0.9,0.999,0]]
    optimiser_params_names::Vector{Vector{String}} = [[],["ρ"],
      ["ρ"],["ρ"],
      ["β1","β2"],
      ["β1","β2"],
      ["β1","β2"],[],
      ["ρ"],["β1","β2"],
      ["β1","β2"],
      ["β1","β2","Weight decay"]]
    allow_lr_change::Bool = true
    learning_rate::Float64 = 1e-3
    epochs::Int64 = 1
    batch_size::Int64 = 10
    savepath::String = "./"
end
hyperparameters_training = Hyperparameters_training()

@with_kw mutable struct General_training
    weight_accuracy::Bool = true
    test_data_fraction::Float64 = 0
    testing_frequency::Float64 = 5
end
general_training = General_training()

@with_kw mutable struct Training_options
    General::General_training = general_training
    Processing::Processing_training = processing_training
    Hyperparameters::Hyperparameters_training = hyperparameters_training
end
training_options = Training_options()

@with_kw mutable struct Design
    width::Float64 = 340
    height::Float64 = 100
    min_dist_x::Float64 = 40
    min_dist_y::Float64 = 40
end
design = Design()

@with_kw mutable struct Training
    Options::Training_options = training_options
    Design::Design = design
    problem_type::Tuple{String,Int64} = ("Segmentation",1)
    input_type::Tuple{String,Int64} = ("Image",0)
    model_url::String = ""
    input_dir::String = ""
    label_dir::String = ""
    name::String = "new"
end
training = Training()

# Validation
@with_kw mutable struct Validation
    model_url::String = ""
    input_dir::String = ""
    label_dir::String = ""
    use_labels::Bool = false
end
validation = Validation()

# Application
@with_kw mutable struct Application_options
    savepath::String = ""
    apply_by::Tuple{String,Int64} = ("file",0)
    data_type::Int64 = 0
    image_type::Int64 = 0
    downsize::Int64 = 0
    skip_frames::Int64 = 0
    scaling::Float64 = 1
    minibatch_size::Int64 = 1
end
application_options = Application_options()

@with_kw mutable struct Application
    Options::Application_options = application_options
    model_url::String = ""
    input_dir::String = ""
    checked_folders::Vector{String} = String[]
end
application = Application()

# Visualisation
@with_kw mutable struct Visualisation
    a::Int = 0
end
visualisation = Visualisation()

# Settings
@with_kw mutable struct Settings
    Main::Main_s = main
    Options::Options = options
    Training::Training = training
    Validation::Validation = validation
    Application::Application = application
    Visualisation::Visualisation = visualisation
end
settings = Settings()

#---Other

mutable struct Counter
    iteration::Int
    Counter() = new(0)
end
(c::Counter)() = (c.iteration += 1)