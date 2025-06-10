process DORADO_BASECALL {
    tag "$meta.id"
    label 'process_high'
    // Patch this module in your pipline if GPU is available
    // label 'process_gpu'

    container 'docker.io/nanoporetech/dorado:sha8bc19cc3c78c1ce847fbf4a879cad997b7e8c430'

    input:
    tuple val(meta), path(pod5s, stageAs: "pod5s/*")
    val model_complex
    val is_duplex

    output:
    tuple val(meta), path("*.ubam")    , emit: ubam  , optional: true
    tuple val(meta), path("*.fastq.gz"), emit: fastq , optional: true
    tuple val(meta), path("*.sam")     , emit: sam   , optional: true
    path "versions.yml"                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "DORADO_BASECALL module does not support Conda. Please use Docker / Singularity / Podman instead."
    }
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def caller = is_duplex ? 'duplex' : 'basecaller'
    def extension = args.contains("--emit-fastq") ? "fastq" :
                    args.contains("--emit-sam")   ? "sam"   :
                    "ubam"
    """
    if [[ "${extension}" == "fastq" ]]; then
        dorado \\
            $caller \\
            $model_complex \\
            $pod5s \\
            -x auto \\
            $args \\
            | gzip > ${prefix}.fastq.gz
    else
        dorado \\
            $caller \\
            $model_complex \\
            $pod5s \\
            -x auto \\
            $args \\
            > ${prefix}.${extension}
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dorado: \$(dorado --version 2>&1 | sed -n '1p')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def extension = args.contains("--emit-fastq") ? "fastq.gz" :
                    args.contains("--emit-sam")   ? "sam"      :
                    "ubam"
    """
    touch ${prefix}.${extension}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dorado: \$(dorado --version 2>&1 | sed -n '1p')
    END_VERSIONS
    """
}
