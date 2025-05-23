process GATK4_INTERVALLISTTOOLS {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/b2/b28daf5d9bb2f0d129dcad1b7410e0dd8a9b087aaf3ec7ced929b1f57624ad98/data':
        'community.wave.seqera.io/library/gatk4_gcnvkernel:e48d414933d188cd' }"

    input:
    tuple val(meta), path(intervals)

    output:
    tuple val(meta), path("*_split/*/*.interval_list"), emit: interval_list
    path "versions.yml"                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    def avail_mem = 3072
    if (!task.memory) {
        log.info '[GATK IntervalListTools] Available memory not known - defaulting to 3GB. Specify process memory requirements to change this.'
    } else {
        avail_mem = (task.memory.mega*0.8).intValue()
    }
    """

    mkdir ${prefix}_split

    gatk --java-options "-Xmx${avail_mem}M -XX:-UsePerfData" \\
        IntervalListTools \\
        --INPUT $intervals \\
        --OUTPUT ${prefix}_split \\
        --TMP_DIR . \\
        $args

    python3 <<CODE
    import glob, os
    # The following python code snippet rename the output files into different name to avoid overwriting or name conflict
    intervals = sorted(glob.glob("*_split/*/*.interval_list"))
    for i, interval in enumerate(intervals):
        (directory, filename) = os.path.split(interval)
        newName = os.path.join(directory, str(i + 1) + filename)
        os.rename(interval, newName)
    CODE

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gatk4: \$(echo \$(gatk --version 2>&1) | sed 's/^.*(GATK) v//; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}_split/temp_0001_of_6
    mkdir -p ${prefix}_split/temp_0002_of_6
    mkdir -p ${prefix}_split/temp_0003_of_6
    mkdir -p ${prefix}_split/temp_0004_of_6
    touch ${prefix}_split/temp_0001_of_6/1scattered.interval_list
    touch ${prefix}_split/temp_0002_of_6/2scattered.interval_list
    touch ${prefix}_split/temp_0003_of_6/3scattered.interval_list
    touch ${prefix}_split/temp_0004_of_6/4scattered.interval_list

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gatk4: \$(echo \$(gatk --version 2>&1) | sed 's/^.*(GATK) v//; s/ .*\$//')
    END_VERSIONS
    """
}
