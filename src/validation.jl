
#---Data preparation

# Get urls of files in selected folders

function get_urls_validation_main(model_data::ModelData,validation_data::ValidationData)
    url_inputs = validation_data.url_inputs
    url_labels = validation_data.url_labels
    if input_type() == :Image
        allowed_ext = ["png","jpg","jpeg"]
    end
    if problem_type() == :Classification
        input_urls,dirs = get_urls1(url_inputs,allowed_ext)
        labels = map(class -> class.name,model_data.classes)
        if issubset(dirs,labels)
            validation_data.use_labels = true
            labels_int = map((label,l) -> repeat([findfirst(label.==labels)],l),dirs,length.(input_urls))
            validation_data.labels_classification = reduce(vcat,labels_int)
        end
    elseif problem_type() == :Regression
        input_urls_raw,_,filenames_inputs_raw = get_urls1(url_inputs,allowed_ext)
        input_urls = input_urls_raw[1]
        filenames_inputs = filenames_inputs_raw[1]
        if validation_data.use_labels==true
            input_urls_copy = copy(input_urls)
            filenames_inputs_copy = copy(filenames_inputs)
            filenames_labels,loaded_labels = load_regression_data(validation_data.url_labels)
            intersect_regression_data!(input_urls_copy,filenames_inputs_copy,
                loaded_labels,filenames_labels)
            if isempty(loaded_labels)
                validation_data.use_labels = false
                @warn string("No file names in ",url_labels ," correspond to file names in ",url_inputs," . Files were loaded without labels.")
            else
                validation_data.labels_regression = loaded_labels
                input_urls = input_urls_copy
            end
        end
    elseif problem_type() == :Segmentation
        if validation_data.use_labels==true
            input_urls,label_urls,_,_,_ = get_urls2(url_inputs,url_labels,allowed_ext)
            validation_data.label_urls = reduce(vcat,label_urls)
        else
            input_urls,_ = get_urls1(url_inputs,allowed_ext)
        end
    end
    validation_data.input_urls = reduce(vcat,input_urls)
    return nothing
end

function prepare_validation_data(classes::Vector{ImageClassificationClass},ind::Int64,
        model_data::ModelData,validation_data::ValidationData,processing_options::ProcessingOptions)
    original = load_image(validation_data.input_urls[ind])
    if processing_options.grayscale
        data_input = image_to_gray_float(original)[:,:,:,:]
    else
        data_input = image_to_color_float(original)[:,:,:,:]
    end
    if validation_data.use_labels
        num = length(classes)
        labels_temp = Vector{Float32}(undef,num)
        fill!(labels_temp,0)
        label_int = validation_data.labels_classification[ind]
        labels_temp[label_int] = 1
        labels = reshape(labels_temp,:,1)
    else
        labels = Array{Float32,2}(undef,0,0)
    end
    return data_input,labels,original
end

function prepare_validation_data(classes::Vector{ImageRegressionClass},ind::Int64,
        model_data::ModelData,validation_data::ValidationData,processing_options::ProcessingOptions)
    original = load_image(validation_data.input_urls[ind])
    original = imresize(original,model_data.input_size[1:2])
    if processing_options.grayscale
        data_input = image_to_gray_float(original)[:,:,:,:]
    else
        data_input = image_to_color_float(original)[:,:,:,:]
    end
    
    if validation_data.use_labels
        labels = reshape(validation_data.labels_regression[ind],:,1)
    else
        labels = Array{Float32,2}(undef,0,0)
    end
    return data_input,labels,original
end

function prepare_validation_data(classes::Vector{ImageSegmentationClass},ind::Int64,
        model_data::ModelData,validation_data::ValidationData,processing_options::ProcessingOptions)
    inds,labels_color,labels_incl,border,border_thickness = get_class_data(classes)
    original = load_image(validation_data.input_urls[ind])
    if processing_options.grayscale
        data_input = image_to_gray_float(original)[:,:,:,:]
    else
        data_input = image_to_color_float(original)[:,:,:,:]
    end
    if validation_data.use_labels
        label = load_image(validation_data.label_urls[ind])
        label_bool = label_to_bool(label,inds,labels_color,
            labels_incl,border,border_thickness)
        data_label = convert(Array{Float32,3},label_bool)[:,:,:,:]
    else
        data_label = Array{Float32,4}(undef,1,1,1,1)
    end
    return data_input,data_label,original
end

#---Makes output images
function get_error_image(predicted_bool_feat::BitArray{2},truth::BitArray{2})
    correct = predicted_bool_feat .& truth
    false_pos = copy(predicted_bool_feat)
    false_pos[truth] .= false
    false_neg = copy(truth)
    false_neg[predicted_bool_feat] .= false
    s = (3,size(predicted_bool_feat)...)
    error_bool = BitArray{3}(undef,s)
    error_bool[1,:,:] .= false_pos
    error_bool[2,:,:] .= false_pos
    error_bool[1,:,:] = error_bool[1,:,:] .| false_neg
    error_bool[2,:,:] = error_bool[2,:,:] .| correct
    return error_bool
end

function compute(validation_data::ValidationData,predicted_bool::BitArray{3},
        label_bool::BitArray{3},labels_color::Vector{Vector{N0f8}},
        num_feat::Int64)
    num = size(predicted_bool,3)
    predicted_data = Vector{Tuple{BitArray{2},Vector{N0f8}}}(undef,num)
    target_data = Vector{Tuple{BitArray{2},Vector{N0f8}}}(undef,num)
    error_data = Vector{Tuple{BitArray{3},Vector{N0f8}}}(undef,num)
    color_error = ones(N0f8,3)
    for i = 1:num
        color = labels_color[i]
        predicted_bool_feat = predicted_bool[:,:,i]
        predicted_data[i] = (predicted_bool_feat,color)
        if validation_data.use_labels
            if i>num_feat
                target_bool = label_bool[:,:,i-num_feat]
            else
                target_bool = label_bool[:,:,i]
            end
            target_data[i] = (target_bool,color)
            error_bool = get_error_image(predicted_bool_feat,target_bool)
            error_data[i] = (error_bool,color_error)
        end
    end
    return predicted_data,target_data,error_data
end

function output_images(predicted_bool::BitArray{3},label_bool::BitArray{3},
        classes::Vector{<:AbstractClass},validation_data::ValidationData)
    class_inds,labels_color, _ ,border = get_class_data(classes)
    labels_color = labels_color[class_inds]
    labels_color_uint = convert(Vector{Vector{N0f8}},labels_color/255)
    inds_border = findall(border)
    border_colors = labels_color_uint[findall(border)]
    labels_color_uint = vcat(labels_color_uint,border_colors,border_colors)
    array_size = size(predicted_bool)
    num_feat = array_size[3]
    num_border = sum(border)
    if num_border>0
        border_bool = apply_border_data(predicted_bool,classes)
        predicted_bool = cat3(predicted_bool,border_bool)
    end
    for i=1:num_border 
        min_area = classes[inds_border[i]].min_area
        ind = num_feat + i
        if min_area>1
            temp_array = predicted_bool[:,:,ind]
            areaopen!(temp_array,min_area)
            predicted_bool[:,:,ind] .= temp_array
        end
    end
    predicted_data,target_data,error_data = compute(validation_data,
        predicted_bool,label_bool,labels_color_uint,num_feat)
    return predicted_data,target_data,error_data
end

function process_output(predicted::AbstractArray{Float32,2},label::AbstractArray{Float32,2},
        original::Array{RGB{N0f8},2},other_data::NTuple{2, Float32},classes::Vector{ImageClassificationClass},
        validation_data::ValidationData,channels::Channels)
    class_names = map(x-> x.name,classes)
    predicted_vec = Iterators.flatten(predicted)
    predicted_int = findfirst(predicted_vec .== maximum(predicted_vec))
    predicted_string = class_names[predicted_int]
    if validation_data.use_labels
        label_vec = Iterators.flatten(label)
        label_int = findfirst(label_vec .== maximum(label_vec))
        label_string = class_names[label_int]
    else
        label_string = ""
    end
    image_data = (predicted_string,label_string)
    data = (image_data,other_data,original)
    # Return data
    put!(channels.validation_results,data)
    put!(channels.validation_progress,1)
    return nothing
end

function process_output(predicted::AbstractArray{Float32,2},label::AbstractArray{Float32,2},
        original::Array{RGB{N0f8},2},other_data::NTuple{2, Float32},classes::Vector{ImageRegressionClass},
        validation_data::ValidationData,channels::Channels)
    image_data = (predicted[:],label[:])
    data = (image_data,other_data,original)
    # Return data
    put!(channels.validation_results,data)
    put!(channels.validation_progress,1)
    return nothing
end

function process_output(predicted::AbstractArray{Float32,4},data_label::AbstractArray{Float32,4},
        original::Array{RGB{N0f8},2},other_data::NTuple{2, Float32},classes::Vector{ImageSegmentationClass},
        validation_data::ValidationData,channels::Channels)
    predicted_bool = predicted[:,:,:,1].>0.5
    label_bool = data_label[:,:,:,1].>0.5
    # Get output data
    predicted_data,target_data,error_data = 
        output_images(predicted_bool,label_bool,classes,validation_data)
    image_data = (predicted_data,target_data,error_data)
    data = (image_data,other_data,original)
    # Return data
    put!(channels.validation_results,data)
    put!(channels.validation_progress,1)
    return nothing
end

"""
    remove_validation_data()

Removes all validation data except for result.
"""
function remove_validation_data()
    if input_type()==:Image
        if problem_type()==:Classification
            data = validation_data.ImageClassificationResults
            fields = fieldnames(ValidationImageRegressionResults)
        elseif problem_type()==:Regression
            data = validation_data.ImageRegressionResults
            fields = fieldnames(ValidationImageRegressionResults)
        elseif problem_type()==:Segmentation
            data = validation_data.ImageSegmentationResults
            fields = fieldnames(ValidationImageSegmentationResults)
        end
    end
    for field in fields
        empty!(getfield(data, field))
    end
end

"""
    remove_validation_results()

Removes validation results.
"""
function remove_validation_results()
    data = validation_data.ImageClassificationResults
    fields = fieldnames(ValidationImageClassificationResults)
    for field in fields
        empty!(getfield(data, field))
    end
    data = validation_data.ImageRegressionResults
    fields = fieldnames(ValidationImageRegressionResults)
    for field in fields
        empty!(getfield(data, field))
    end
    data = validation_data.ImageSegmentationResults
    fields = fieldnames(ValidationImageSegmentationResults)
    for field in fields
        empty!(getfield(data, field))
    end
end

# Main validation function
function validate_main(model_data::ModelData,validation_data::ValidationData,
        options::Options,channels::Channels)
    # Initialisation
    remove_validation_results()
    processing = options.TrainingOptions.Processing
    num = length(validation_data.input_urls)
    put!(channels.validation_progress,num)
    use_labels = validation_data.use_labels
    classes = model_data.classes
    model = model_data.model
    loss = model_data.loss
    ws = get_weights(classes,options)
    accuracy = get_accuracy_func(ws,options)
    use_GPU = false
    if options.GlobalOptions.HardwareResources.allow_GPU
        if has_cuda()
            use_GPU = true
        else
            @warn "No CUDA capable device was detected. Using CPU instead."
        end
    end
    if problem_type()==:Segmentation
        num_slices_val = options.GlobalOptions.HardwareResources.num_slices
        offset_val = options.GlobalOptions.HardwareResources.offset
    else
        num_slices_val = 1
        offset_val = 0
    end
    for i = 1:num
        if check_abort_signal(channels.validation_modifiers)
            return nothing
        end
        data_input,label,other = prepare_validation_data(classes,i,model_data,
            validation_data,processing)
        predicted = forward(model,data_input,num_slices=num_slices_val,offset=offset_val,use_GPU=use_GPU)
        if use_labels
            accuracy_val = accuracy(predicted,label)
            loss_val = loss(predicted,label)
            other_data = (accuracy_val,loss_val)
        else
            other_data = (0.f0,0.f0)
        end
        process_output(predicted,label,other,other_data,classes,validation_data,channels)
    end
    return nothing
end
function validate_main2(model_data::ModelData,validation_data::ValidationData,options::Options,channels::Channels)
    t = Threads.@spawn validate_main(model_data,validation_data,options,channels)
    push!(validation_data.tasks,t)
    return t
end